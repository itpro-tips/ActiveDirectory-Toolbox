function Get-WindowsFirewallStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$ComputerName = $env:COMPUTERNAME
    )

    $netConnectionProfile = Get-NetConnectionProfile -CimSession $ComputerName

    $firewallService = Get-Service mpssvc -ComputerName $ComputerName

    $firewallProfiles = Get-NetFirewallProfile -CimSession $ComputerName
    
    $object = [PSCustomObject][ordered] @{
        ComputerName         = $ComputerName
        NetConnectionProfile = ($netConnectionProfile  | ForEach-Object { "$($_.InterfaceAlias) = $($_.NetworkCategory)" }) -join '|'
        FWStatus             = $firewallService.Status
        FWStartType          = $firewallService.StartType
        DomainProfile        = ($firewallProfiles | Where-Object { $_.Name -eq 'Domain' }).Enabled
        PrivateProfile       = ($firewallProfiles | Where-Object { $_.Name -eq 'Private' }).Enabled
        PublicProfile        = ($firewallProfiles | Where-Object { $_.Name -eq 'Public' }).Enabled
    }

    return $object
}