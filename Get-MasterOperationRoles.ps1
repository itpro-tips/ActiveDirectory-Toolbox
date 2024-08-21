function Get-MasterOperationRoles {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ConvertNTDSToHostName
    )
    $adForest = Get-ADForest
    $adDomain = Get-ADDomain

    $domainDnsZonesOwner = (Get-ADObject "CN=Infrastructure,DC=DomainDnsZones,$($adDomain.DistinguishedName)" -Properties fsmoRoleOwner).fsmoRoleOwner
    $forestDnsZonesOwner = (Get-ADObject "CN=Infrastructure,DC=ForestDnsZones,$($adDomain.DistinguishedName)" -Properties fsmoRoleOwner).fsmoRoleOwner

    if ($ConvertNTDSToHostName.IsPresent) {
        $domainDnsZonesOwner = (Get-ADDomainController -Filter { NTDSSettingsObjectDN -eq $domainDnsZonesOwner }).HostName
        $forestDnsZonesOwner = (Get-ADDomainController -Filter { NTDSSettingsObjectDN -eq $forestDnsZonesOwner }).HostName
    }
    
    $object = [PSCustomObject][ordered] @{
        DomainNamingMaster   = $adForest.DomainNamingMaster
        SchemaMaster         = $adForest.SchemaMaster
        InfrastructureMaster = $adDomain.InfrastructureMaster
        RIDMaster            = $adDomain.RIDMaster
        PDCEmulator          = $adDomain.PDCEmulator
        DomainDnsZonesOwner  = $domainDnsZonesOwner
        ForestDnsZonesOwner  = $forestDnsZonesOwner
    }
    
    return $object
}