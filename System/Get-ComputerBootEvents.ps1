function Get-ComputerBootEvents {
    [CmdletBinding()]
    param (
        [Parameter()]
        [switch]$LastOnly
    )

    [System.Collections.Generic.List[PSObject]]$startEventsArray = @()

    $now = Get-Date

    $lastRebootFromCim = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime

    $fastStartup = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -ErrorAction SilentlyContinue).HiberbootEnabled
    
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

    <#
HiberbootEnabled = 1 = Fast startup is enabled
HiberbootEnabled = 0/not exist = Fast startup is disabled
#>

    $bootEvents = Get-WinEvent -FilterHashtable $filterHashTable

    if ($null -ne $bootEvents) {

        if ($LastOnly) {
            $bootEvents = $bootEvents | Sort-Object -Property TimeCreated -Descending | Select-Object -First 1
        }

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
                BootTime                 = $bootEvent.TimeCreated
                BootTimeDifference       = New-TimeSpan -Start $bootEvent.TimeCreated -End $now
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
            BootTime                 = $lastBoot
            BootTimeDifference       = New-TimeSpan -Start $lastBoot -End $now
            IsLastBootTime           = $true
            FastStartupEnabled       = $fastStartupEnabled
            LastShutdownOrRebootType = 'Unknown'
        }
    }

    return $startEventsArray
}