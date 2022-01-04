Function Get-MasterOperationRoles {
    $adForest = Get-ADForest
    $adDomain = Get-ADDomain

    $object = [PSCustomObject][ordered] @{
        DomainNamingMaster   = $adForest.DomainNamingMaster
        SchemaMaster         = $adForest.SchemaMaster
        InfrastructureMaster = $adDomain.InfrastructureMaster
        RIDMaster            = $adDomain.RIDMaster
        PDCEmulator          = $adDomain.PDCEmulator
        DomainDnsZonesOwner  = (Get-ADObject "CN=Infrastructure,DC=DomainDnsZones,$($adDomain.DistinguishedName)" -Properties fsmoRoleOwner).fsmoRoleOwner
        ForestDnsZonesOwner  = (Get-ADObject "CN=Infrastructure,DC=ForestDnsZones,$($adDomain.DistinguishedName)" -Properties fsmoRoleOwner).fsmoRoleOwner
    }
    
    return $object

}