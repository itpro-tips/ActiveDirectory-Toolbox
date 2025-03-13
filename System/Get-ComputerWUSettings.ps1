
<#
    .SYNOPSIS
    Get Windows Update settings for a computer.

    .DESCRIPTION
    This function will return all Windows Update settings for a computer.

    .PARAMETER ComputerName
    The name of the computer to get Windows Update settings from.

    .EXAMPLE
    Get-ComputerWUSettings
    Get Windows Update settings for the local computer.

    .EXAMPLE
    Get-ComputerWUSettings -ComputerName 'Server01'
    Get Windows Update settings for Server01.

    .EXAMPLE
    Get-ComputerWUSettings | Select-Object WUSettings
    Get Windows Update settings for Server01.
    
    .NOTES
    Need to run as administrator.
    Need PSWindowsUpdate module installed (Install-Module -Name PSWindowsUpdate -Scope CurrentUser)

#>
function Get-ComputerWUSettings {
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    
    Write-Verbose "Get Windows Update settings for $ComputerName"
    if ($ComputerName) {
        $wuSettings = Get-WUSettings -ComputerName $ComputerName
        $wuRebootStatus = Get-WURebootStatus -ComputerName $ComputerName
        $wuJob = Get-WUJob -ComputerName $ComputerName
        $wuLastResults = Get-WULastResults -ComputerName $ComputerName

        # the following cmdlets have some problems when run on remote computers so we will not run them
        #$wuHistory = Get-WUHistory -ComputerName $ComputerName
        #$wuServiceManager = Get-WUServiceManager -ComputerName $ComputerName
        #$wuApiVersion = Get-WUApiVersion -ComputerName $ComputerName
        #$wuInstallerStatus = Get-WUInstallerStatus -ComputerName $ComputerName
    }
    else {
        $computerName = $env:COMPUTERNAME
        $wuSettings = Get-WUSettings    
        $wuRebootStatus = Get-WURebootStatus
        $wuJob = Get-WUJob
        $wuLastResults = Get-WULastResults

        # the following cmdlets have some problems when run on remote computers so we will not run them on remote computers
        #$wuHistory = Get-WUHistory
        #$wuServiceManager = Get-WUServiceManager
        #$wuApiVersion = Get-WUApiVersion
        #$wuInstallerStatus = Get-WUInstallerStatus
    }

    # create custom object with all Windows Update settings
    <#$wuSettingsArray = @{
        'WUSettings'     = $wuSettings
        'WURebootStatus' = $wuRebootStatus
        'WUJob'          = $wuJob
        'WULastResults'  = $wuLastResults
        #'WUHistory'         = $wuHistory
        #'WUServiceManager'  = $wuServiceManager
        #'WUApiVersion'      = $wuApiVersion
        #'WUInstallerStatus' = $wuInstallerStatus
    }
        #>

    $object = [PSCustomObject][ordered]@{
        ComputerName                = $computerName
        AUOptions                   = $wuSettings.AUOptions
        NoAutoUpdate                = $wuSettings.NoAutoUpdate
        LastSearchSuccessDate       = $wuLastResults.LastSearchSuccessDate
        LastInstallationSuccessDate = $wuLastResults.LastInstallationSuccessDate
        RebootRequired              = $wuRebootStatus.RebootRequired
        RebootScheduled             = $wuRebootStatus.RebootScheduled

    }       

    return $object    
}