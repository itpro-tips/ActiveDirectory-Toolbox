Import-Module ActiveDirectory

$rootdse = Get-ADRootDSE

# 'Replicating Directory Changes' and 'Replicating Directory Changes All' have the same rightsGUID
# so we check only the first one
$replicationPermission = 'Replicating Directory Changes'
$replicationAllPermission = 'Replicating Directory Changes All'
$replicationFilteredSet = 'Replicating Directory Changes in Filtered Set'

# look for rightsGUID
$repl = (Get-ADObject -SearchBase ($rootdse.ConfigurationNamingContext) -LDAPFilter "(&(objectclass=controlAccessRight)(DisplayName=$replicationPermission))" -Properties rightsGUID).rightsGuid
$replAll = (Get-ADObject -SearchBase ($rootdse.ConfigurationNamingContext) -LDAPFilter "(&(objectclass=controlAccessRight)(DisplayName=$replicationAllPermission))" -Properties rightsGUID).rightsGuid
$replFiltered = (Get-ADObject -SearchBase ($rootdse.ConfigurationNamingContext) -LDAPFilter "(&(objectclass=controlAccessRight)(DisplayName=$replicationFilteredSet))" -Properties rightsGUID).rightsGuid

# Get the ACL on the domain object to find the objects with 'Replicating Directory Changes' permission
$domainDN = (Get-ADDomain).DistinguishedName
$aclOnDomain = Get-ACL "AD:$domainDN"

"Replicating Directory Changes:"
[System.Collections.Generic.List[PSObject]]$dcSyncPermissionsArray = @()

$aclOnDomain.Access | Where-Object { $_.ObjectType -eq $repl -or $_.ObjectType -eq $replAll -or $_.ObjectType -eq $replFiltered } | ForEach-Object {
    
    switch ($_.ObjectType ) {
        $repl {
            $permission = $replicationPermission
            break
        }
        $replAll {
            $permission = $replicationAllPermission
            break
        }
        $replFiltered {
            $permission = $replicationFilteredSet
            break
        }
        Default {
            $permission = $null
            break
        }
    }
    

    $object = [PSCustomObject][ordered]@{
        IdentityReference = $_.IdentityReference
        Permission        = $permission
    }
    $dcSyncPermissionsArray.Add($object)
}

return $dcSyncPermissionsArray