function Get-WindowsFirewallStatus {
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )

    if ($ComputerName -and $ComputerName -ne 'localhost') {
        $firewallService = Invoke-Command -ComputerName $ComputerName -ScriptBlock { Get-Service mpssvc }
        $CimData = [ordered] @{
            CimSession = $ComputerName
        }
        
        $netConnectionProfile = Get-NetConnectionProfile @CimData

        $firewallProfiles = Get-NetFirewallProfile @CimData
    }
    else {
        $firewallService = Get-Service mpssvc
        $netConnectionProfile = Get-NetConnectionProfile

        $firewallProfiles = Get-NetFirewallProfile
    }    
    
    $object = [PSCustomObject][ordered] @{
        ComputerName         = $ComputerName
        NetConnectionProfile = ($netConnectionProfile | ForEach-Object { "$($_.InterfaceAlias) = $($_.NetworkCategory)" }) -join '|'
        FWStatus             = $firewallService.Status
        FWStartType          = $firewallService.StartType
        DomainProfile        = ($firewallProfiles | Where-Object { $_.Name -eq 'Domain' }).Enabled
        PrivateProfile       = ($firewallProfiles | Where-Object { $_.Name -eq 'Private' }).Enabled
        PublicProfile        = ($firewallProfiles | Where-Object { $_.Name -eq 'Public' }).Enabled
    }

    return $object
}