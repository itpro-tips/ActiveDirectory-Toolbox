#Gets all the SPNS in the domain
 
# Alternative way to get the same information using CMD.exe:
# dsquery * "DC=yourdomain,DC=com" -filter "(&(objectcategory=computer)(servicePrincipalName=*))" -attr distinguishedName servicePrincipalName > spns.txt

#$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
 
#$search.filter = "(servicePrincipalName=*)"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=person))"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=user))"
#$results = $search.Findall()

function Get-ServicePrincipalNames {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Computers')]
        [String[]]$ObjectType
    )

    if ($ObjectType -eq 'Users' ) {
        $filter = '(&(servicePrincipalName=*)(objectCategory=user))'
    }
    elseif ($ObjectType -eq 'Computers') {
        $filter = '(&(servicePrincipalName=*)(objectCategory=computer))'
    }
    else {
        $filter = '(servicePrincipalName=*)'
    }

    $objectsWithSPN = Get-ADObject -LDAPFilter $filter -Properties UserPrincipalName, ObjectCategory, SamAccountName, ServicePrincipalName, AdminCount

    [System.Collections.Generic.List[PSObject]]$SPNObjects = @()

    foreach ($userWithSPN in $objectsWithSPN) {
        $object = [PSCustomObject][ordered]@{
            Name                 = $userWithSPN.Name
            SamAccountName       = $userWithSPN.SamAccountName
            DistinguishedName    = $userWithSPN.distinguishedName
            ServicePrincipalName = $userWithSPN.ServicePrincipalName -join '|'
            ObjectCategory       = $userWithSPN.ObjectCategory
            AdminCount           = if ($userWithSPN.adminCount -ne 1) { 'null' }else { $userWithSPN.admincount }
        }
    
        $SPNObjects.Add($object) 
    }

    return $SPNObjects
}