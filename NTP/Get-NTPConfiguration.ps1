<#
.SYNOPSIS
    Get Time Synchronization Type

.DESCRIPTION
    Get Time Synchronization Type using w32tm.exe.PowerShell has to be executed as admistrator.

    Type Value  Meaning:
    ----------------------
	NoSync:	Does not synchronize time.
  
	NTP:    Synchronizes time to the time sources specified in the Parameters\NTPServer entry.
  
	NT5DS:	Synchronizes time to the domain hierarchy.
 
	AllSync:Uses all synchronization mechanisms available.

.PARAMETER Computers
    The computer name(s) to retrieve the info from. 
    Default to local Computer

.PARAMETER DomainControllers
	Switch to query all doman controllers in the current domain
	
.EXAMPLE
    Get-NTPConfiguration -Computers Server1

    ComputerName : Server1
    Type         : NT5DS
    Description  : The time service synchronizes from the domain hierarchy.

.EXAMPLE
    Get-NTPConfiguration -DomainControllers
	
.EXAMPLE
    Get-NTPConfiguration -Computers DC1

    ComputerName : DC1
    Type         : NTP
    Description  : The time service synchronizes from timeserver.Internet.net,0x2 
                   servers specified in the NTPServer registry entry.

    DC1 is a Root Domain Controller PDC that synchronize to an external source
  
.EXAMPLE
    Get-NTPConfiguration -Computers DC1,DC2
  
.INPUTS
    System.String, you can pipe ComputerNames to this Function

.OUTPUTS
    Custom PSObjects 

.NOTES

    AUTHOR: Pasquale Lantella 
    LASTEDIT: Bastien Perez (ITPro-Tips.com 27/10/2021) - Add w32time status (running, etc.) and AnnounceFlags value for domain controller
    KEYWORDS: Time Synchronization Type/
	SOURCES : https://scriptingblog.com/2014/07/31/get-windows-time-settings-from-remote-servers/ and https://gallery.technet.microsoft.com/scriptcenter/Get-Time-Synchronization-76a01118

.LINK
    Registry entries for the W32Time service
    http://support.microsoft.com/en-us/kb/223184

#Requires -Version 3.0
#>

Function Get-NTPConfiguration {
    Param(

        [Parameter(Position = 0, ValueFromPipeline = $True,
            HelpMessage = 'An array (comma separated) of computer names. The default is the local computer.')]
        [alias("CN")]
        [string[]]$ComputerName = $Env:COMPUTERNAME,
        [switch]$DomainControllers
    )

    BEGIN {

        Set-StrictMode -Version Latest
        ${CmdletName} = $Pscmdlet.MyInvocation.MyCommand.Name

        $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
        if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Write-Warning "Please run PowerShell as administrator"
            exit
        }

        $command = 'w32tm.exe'
        Try { Get-Command -Name $command -ErrorAction stop | Out-Null }
        Catch { Write-Error "[$command] does not exist"; break }

        Function Get-AnnounceFlagsValue ([int]$AnnounceFlags) {
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

        Function Get-RemoteTime {

            [CmdletBinding()]
            [OutputType([datetime])]
            param (
                $server
            )
        
            Process {
                $remoteOSInfo = Get-WmiObject win32_OperatingSystem -computername $server   
                [datetime]$remoteDateTime = $remoteOSInfo.convertToDatetime($remoteOSInfo.LocalDateTime)    
                return $remoteDateTime
            }
        }

    } # end BEGIN

    PROCESS {
        $NTPConfigurations = New-Object System.Collections.ArrayList
	
        if ($domainControllers) {
            $ComputerName = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
        }
        foreach ($computer in $ComputerName) {
            Write-Verbose "Processing $computer"
            if (Test-Connection -ComputerName $computer -count 1 -quiet) {
                $parametersSubkeyArguments = '/dumpreg', "/computer:$computer", '/subkey:parameters' 

                $w32tmResults = w32tm.exe $parametersSubkeyArguments 
                $typeSync = $w32tmResults | Select-String -Pattern "Type                       REG_SZ"
    
                $type = $typeSync.Line.Substring(47).trim()

                switch ($type) {
                    'NoSync' {
                        Write-Output "The time service does not synchronize with other sources."
                    }
                    'NTP' {
                        $NTPServer = $w32tmResults | Select-String -Pattern "NTPServer"
                        $NTPServer = $NTPServer.Line.Substring(47).trim() 
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
			
                $NTPSource = w32tm.exe /query /computer:$computer /source
			
                $timeZone = (Get-WmiObject win32_timeZone -ComputerName $computer).caption 
			
                $remoteTime = Get-RemoteTime -Server $computer
			
                $temp = w32tm /query /status /computer:$computer | Select-Object -Skip 6
			
                $lastSync = (($temp | Select-Object -First 1) -Split ": ")[1]
                $pollInterval = $temp | Select-Object -Skip 2 -First 1
                $w32tm = Get-Service -Name w32time -ComputerName $computer
            
                $w32tmStatus = $w32tm.Status
            
                if ($w32tmStatus -ne 'Running') {
                    $w32tmStatus = "$w32tm - Not launched!"
                }

                if ($DomainControllers) {
                    #$w32timeconfigKey = Invoke-command -ComputerName $computer { Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config' } 
                    $parametersSubkeyConfig = '/dumpreg', "/computer:$computer", '/subkey:config' 
            
                    $w32tmResultsConfig = w32tm.exe $parametersSubkeyConfig 
                    $aFlag = $w32tmResultsConfig | Select-String AnnounceFlags
                    $aFlag = $aFlag.Line.Substring(46).trim()
                    $AnnounceFlagValue = Get-AnnounceFlagsValue -AnnounceFlags $aFlag
                }
                else {
                    $AnnounceFlagValue = '-'
                }

                $outputObject = New-Object PSObject -Property ([ordered]@{
    
                        Name             = $computer
                        Type             = $type
                        Description      = $syncType
                        Source           = $NTPSource
                        TimeZone         = $timeZone
                        RemoteTime       = $remoteTime
                        LastSync         = $lastSync
                        PollInterval     = $pollInterval
                        Win32TimeService = $w32tmStatus
                        AnnounceFlag     = $AnnounceFlagValue
				
                    })
    
                $null = $NTPConfigurations.Add($outputObject)
            }              
            Else {
                Write-Warning "\\$computer DO NOT reply to ping" 
            } # end IF (Test-Connection -ComputerName $computer -count 2 -quiet)
      
        } # end ForEach ($computer in $computerName)

        return $NTPConfigurations
	
    } # end PROCESS

    END { Write-Verbose "Function ${CmdletName} finished." }

} # end Function Get-NTPConfiguration