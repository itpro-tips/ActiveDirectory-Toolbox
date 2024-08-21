function Get-MasterOperationRoles {
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ConvertNTDSToHostName
    )
    $adForest = Get-ADForest
    $adDomain = Get-ADDomain

    $object = [PSCustomObject][ordered] @{
        DomainNamingMaster   = $adForest.DomainNamingMaster
        SchemaMaster         = $adForest.SchemaMaster
        InfrastructureMaster = $adDomain.InfrastructureMaster
        RIDMaster            = $adDomain.RIDMaster
        PDCEmulator          = $adDomain.PDCEmulator
    }
    
    # Application Partition can be DC=DomainDnsZones,DC=domain,DC=com or DC=ForestDnsZones,DC=domain,DC=com or maybe custom partition
    $adForest.ApplicationPartitions | Where-Object { $_ -like '*DC=*,DC=*' } | ForEach-Object {
        # can be DC=name,DC=domain,DC=com. W want to extract the name part
        $applicationPartitionName = $_.Split(',')[0].Split('=')[1]
        $fsmoRolesOwner = (Get-ADObject -Identity "CN=Infrastructure,$($_)" -Properties fsmoRoleOwner).fsmoRoleOwner
        
        if ($ConvertNTDSToHostName.IsPresent) {
            $fsmoRolesOwner = (Get-ADDomainController -Filter { NTDSSettingsObjectDN -eq $fsmoRolesOwner }).HostName
        }

        $object | Add-Member -MemberType NoteProperty -Name $applicationPartitionName -Value $fsmoRolesOwner
    }

    return $object
}