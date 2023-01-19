function Get-ComputerBootEvents {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$ComputerName,
        [Parameter(Mandatory = $false)]
        [switch]$LastOnly

    )

    # credits to https://4sysops.com/archives/format-time-and-date-output-of-powershell-new-timespan/
    function Get-TimeSpanToString {
        <#
    .Synopsis
    Displays the time span between two dates in a single line, in an easy-to-read format
    .DESCRIPTION
    Only non-zero weeks, days, hours, minutes and seconds are displayed.
    If the time span is less than a second, the function display "Less than a second."
    .PARAMETER TimeSpan
    Uses the TimeSpan object as input that will be converted into a human-friendly format
    .EXAMPLE
    Get-TimeSpanPretty -TimeSpan $TimeSpan
    Displays the value of $TimeSpan on a single line as number of weeks, days, hours, minutes, and seconds.
    .EXAMPLE
    $LongTimeSpan | Get-TimeSpanPretty
    A timeline object is accepted as input from the pipeline. 
    The result is the same as in the previous example.
    .OUTPUTS
    String(s)
    .NOTES
    Last changed on 28 July 2022
    #>

        [CmdletBinding()]
        Param
        (
            [Parameter(Mandatory, ValueFromPipeline)]
            [ValidateNotNull()][timespan]$TimeSpan
        )

        # Initialize $timeSpanToString, in case there is more than one timespan in the input via pipeline
        [string]$timeSpanToString = ''
    
        $blocks = [ordered]@{
            weeks   = [math]::Floor($TimeSpan.Days / 7)
            days    = [int]$TimeSpan.Days % 7
            hours   = [int]$TimeSpan.Hours
            minutes = [int]$TimeSpan.Minutes
            seconds = [int]$TimeSpan.Seconds
        } 

        # Process each item in $parts (week, day, etc.)
        foreach ($part in $blocks.Keys) {

            # Skip if zero
            if ($blocks.$part -ne 0) {
                # Append the value and key to the string
                $timeSpanToString += "{0} {1}, " -f $blocks.$part, $part
            }
        }
    
        # If the $timeSpanToString is not 0 (which could happen if start and end time are identical)
        if ($timeSpanToString.Length -ne 0) {
            # delete the last coma and space
            $timeSpanToString = $timeSpanToString.Substring(0, $timeSpanToString.Length - 2)
        }
        else {
            # Display string instead of an empty string
            $timeSpanToString = 'Less than a second'
        }

        return $timeSpanToString

    }

    [System.Collections.Generic.List[PSObject]]$startEventsArray = @()

    $now = Get-Date

    if ($ComputerName) {
        $lastRebootFromCim = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
        }
    }
    else {
        $lastRebootFromCim = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }
    
    <#
    HiberbootEnabled = 1 = Fast startup is enabled
    HiberbootEnabled = 0/not exist = Fast startup is disabled
    #>
    if ($ComputerName) {
        $fastStartup = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction SilentlyContinue).HiberbootEnabled
        }
    }
    else {
        $fastStartup = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction SilentlyContinue).HiberbootEnabled
    }    
    
    if ($fastStartup -eq 1) {
        Write-Verbose 'Fast startup is enabled. Checking for 0x1 event ID 27 to get shutdown with fast boot'
        $fastStartupEnabled = $true
        #    $bootEvent = Get-WinEvent -FilterHashtable $filterHashTable | Where-Object { $_.message -match '0x1' }
    }
    else {
        Write-Verbose 'Fast startup is disabled. Checking for 0x0 event ID 27 to get full shutdown or reboot'
        $fastStartupEnabled = $false
        #$bootEvent = Get-WinEvent -FilterHashtable $filterHashTable | Where-Object { $_.message -match '0x0' }
    }

    $filterHashTable = @{
        LogName      = 'System'
        ProviderName = 'Microsoft-Windows-Kernel-Boot'
        ID           = 27
    }
    
    $eventParams = @{
        FilterHashtable = $filterHashTable
    }

    if ($LastOnly) {
        $eventParams.Add('MaxEvents', 1)
    }

    if ($ComputerName) {
        $bootEvents = Invoke-Command -ComputerName $computerName -ArgumentList $eventParams -ScriptBlock {
            Param($eventParams)
            Get-WinEvent @eventParams
        }
    }
    else {
        $computerName = $env:COMPUTERNAME
        $bootEvents = Get-WinEvent @eventParams
    }   
    
    if ($null -ne $bootEvents) {

        <# if ($LastOnly) {
            $bootEvents = $bootEvents | Sort-Object -Property TimeCreated -Descending | Select-Object -First 1
        } #>

        $isLastBootTime = $true

        foreach ($bootEvent in $bootEvents) {
            <# eventID 27 message
        0x0: Full shutdown or reboot
        0x1: Shutdown with fast boot
        0x2: Resume from hibernation
        #>
            switch -regex ($bootEvent.message) {
                '0x0' {
                    $lastShutdownOrRebootType = 'Full shutdown or reboot (0x0)'
                    break
                }
                '0x1' {
                    $lastShutdownOrRebootType = 'Shutdown with fast boot (0x1)'
                    break
                }
                '0x2' {
                    $lastShutdownOrRebootType = 'Resume from hibernation (0x2)'
                    break
                }
                default {
                    $lastShutdownOrRebootType = "Unknown $($bootEvent.message)"
                    break
                }
            }

            $object = [PSCustomObject][ordered]@{
                ComputerName             = $ComputerName
                BootTime                 = $bootEvent.TimeCreated
                BootTimeDifference       = New-TimeSpan -Start $bootEvent.TimeCreated -End $now | Get-TimeSpanToString
                BootTimeDifferenceRaw    = New-TimeSpan -Start $bootEvent.TimeCreated -End $now
                IsLastBootTime           = $isLastBootTime
                FastStartupEnabled       = $fastStartupEnabled
                LastShutdownOrRebootType = $lastShutdownOrRebootType
            }

            $startEventsArray.Add($object)

            $isLastBootTime = $false
        }
    }
    else {
        Write-Verbose 'No boot event found (i.e no event log with ID 27, either because not exist or newer event logs overwritten older event 27 logs), use last reboot time from Win32_OperatingSystem'
        $lastBoot = $lastRebootFromCim

        $object = [PSCustomObject][ordered]@{
            ComputerName             = $ComputerName
            BootTime                 = $lastBoot
            BootTimeDifference       = New-TimeSpan -Start $lastBoot -End $now | Get-TimeSpanToString
            BootTimeDifferenceRaw    = New-TimeSpan -Start $bootEvent.TimeCreated -End $now
            IsLastBootTime           = $true
            FastStartupEnabled       = $fastStartupEnabled
            LastShutdownOrRebootType = 'Unknown'
        }
    }

    return $startEventsArray
}