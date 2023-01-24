#Requires -Version 3.0
<#
.SYNOPSIS
    Get Time Synchronization Type

.DESCRIPTION
    Get Time Synchronization Type using w32tm.exe.PowerShell has to be executed as admistrator.

.PARAMETER ComputerName
    The computer name(s) to retrieve the info from. 
    Default to local Computer

.PARAMETER DomainControllers
	Switch to query all doman controllers in the current domain
	
.EXAMPLE
    Get-NTPConfiguration -ComputerName Server1

.EXAMPLE
    Get-NTPConfiguration -DomainControllers
	
.EXAMPLE
    Get-NTPConfiguration -ComputerName DC1

    ComputerName : DC1
    Type         : NTP
    Description  : The time service synchronizes from timeserver.Internet.net,0x2 
                   servers specified in the NTPServer registry entry.

    DC1 is a Root Domain Controller PDC that synchronize to an external source
  
.EXAMPLE
    Get-NTPConfiguration -ComputerName DC1,DC2
  
.INPUTS
        System.String, you can pipe ComputerNames to this function

.OUTPUTS
    Array of PSCustomObject

.NOTES
  
    By: Bastien Perez (ITPro-Tips.com 24/01/2023) - Add w32time status (running, etc.) and AnnounceFlags value for domain controller
    Use Invoke-Command to run w32tm.exe on remote computers, faster than using WMI andw32tm

    Based on Pasquale Lantella's work (https://scriptingblog.com/2014/07/31/get-windows-time-settings-from-remote-servers/)

#>

function Get-NTPConfiguration {
    Param(

        [Parameter(Position = 0, ValueFromPipeline = $True,
            HelpMessage = 'An array (comma separated) of computer names. The default is the local computer.')]
        [string[]]$ComputerName = $env:COMPUTERNAME,
        [switch]$DomainControllers
    )

    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Warning "Please run PowerShell as administrator"
        return
    }

    function Get-AnnounceFlagsValue ([int]$AnnounceFlags) {
        $AnnounceFlagsHash = @{
            0 = '"Timeserv_Announce_No", Reliable_Timeserv_Announce_No. The domain controller does not advertise time service.'
            1 = '"Timeserv_Announce_Yes". The DC always advertises time service.'
            2 = '"Timeserv_Announce_Auto". The DC automatically determines whether it should advertise time service.'
            4 = '"Reliable_Timeserv_Announce_Yes". The DC will always advertise reliable time service.'
            8 = '"Reliable_Timeserv_Announce_Auto". The DC automatically determines whether it should advertise reliable time service.'
        }

        $AnnounceFlagsValue = $AnnounceFlags

        foreach ($key in $AnnounceFlagsHash.Keys) {
            if (($AnnounceFlags -band $key) -ne 0) {
                $AnnounceFlagsValue = "$AnnounceFlagsValue - $($AnnounceFlagsHash[$key])"
            }
        }

        return $AnnounceFlagsValue
    } 
 
    [System.Collections.Generic.List[PSObject]]$NTPConfigurations = @()
	
    if ($domainControllers) {
        $ComputerName = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
    }

    foreach ($computer in $ComputerName) {
        Write-Verbose "Processing $computer"

        try {
            $session = New-PSSession -ComputerName $computer -ErrorAction SilentlyContinue
        }
        catch {
            Write-Warning "Unable to create a PSSession to $computer"
            continue
        }

        $w32Info = Invoke-Command -Session $session -ScriptBlock {
            $w32timeService = Get-Service -Name w32time
            $w32tmDumpReg = w32tm /dumpreg /subkey:parameters
            $source = w32tm /query /source
            $timeZone = (Get-WmiObject win32_timeZone).Caption

            $temp = w32tm /query /status | Select-Object -Skip 6
            $lastSync = (($temp | Select-Object -First 1) -Split ": ")[1]
            $pollInterval = $temp | Select-Object -Skip 2 -First 1

            $rawLocalDateTime = Get-WmiObject win32_OperatingSystem -Property LocalDateTime
            [datetime]$remoteDateTime = $rawLocalDateTime.convertToDatetime($rawLocalDateTime.LocalDateTime)  
        
            $object = [PSObject][ordered]@{
                Computer       = $env:COMPUTERNAME
                w32timeService = $w32timeService
                w32tmDumpReg   = $w32tmDumpReg
                source         = $source
                timeZone       = $timeZone
                lastSync       = $lastSync
                pollInterval   = $pollInterval
                DateTime       = $remoteDateTime
            }
        
            return $object
        }

        $typeSync = $w32Info.w32tmDumpReg | Select-String -Pattern 'Type                       REG_SZ'
        $type = $typeSync.Line.Substring(47).trim()

        switch ($type) {
            'NoSync' {
                $syncType = "The time service does not synchronize with other sources."
                break
            }
            'NTP' {
                # line is NtpServer                  REG_SZ              fr.pool.ntp.org,0x8
                $NTPServer = ($w32Info.w32tmDumpReg | Select-String -Pattern 'NTPServer').Line.Substring(47).trim() 
                $syncType = "Time synchronization from '$NTPServer' (registry entry)."
                break
            }
            'NT5DS' {
                $syncType = 'Time synchronization from the domain hierarchy. But please check the Source parameters, it MUST be the PDC Emulator.'
                break
            }
            'AllSync' {
                $syncType = 'Time synchronization uses all the available synchronization mechanisms.'
                break
            }
            Default {
                $syncType = 'Unknown.'
                break
            }
        }

        if ($DomainControllers) {
            $w32timeConfigSubkey = Invoke-command -Session $session { w32tm /dumpreg /subkey:config }
            
            $aFlag = $w32timeConfigSubkey | Select-String AnnounceFlags
            $aFlag = $aFlag.Line.Substring(46).trim()

            $AnnounceFlagValue = Get-AnnounceFlagsValue -AnnounceFlags $aFlag
        }
        else {
            $AnnounceFlagValue = '-'
        }

        $object = [PSCustomObject][ordered]@{
            ComputerName     = $computer
            Type             = $type
            Description      = $syncType
            Source           = $w32Info.source
            TimeZone         = $w32Info.timeZone
            RemoteTime       = $w32Info.remoteDateTime
            LastSync         = $w32Info.lastSync
            PollInterval     = $w32Info.pollInterval
            Win32TimeService = $w32Info.w32timeService.Status
            AnnounceFlag     = $AnnounceFlagValue
        }
    
        $NTPConfigurations.Add($object)
    }              

    return $NTPConfigurations
}