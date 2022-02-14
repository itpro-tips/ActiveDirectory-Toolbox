#Gets all the SPNS in the domain
 
# Alternative way to get the same information using CMD.exe:
# dsquery * "DC=yourdomain,DC=com" -filter "(&(objectcategory=computer)(servicePrincipalName=*))" -attr distinguishedName servicePrincipalName > spns.txt

#$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
 
#$search.filter = "(servicePrincipalName=*)"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=person))"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=user))"
#$results = $search.Findall()

#or builitin :
#setspn -T medin -Q */*

function Get-ServicePrincipalNames {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Computers')]
        [String]$ObjectType,
        [boolean[]]$GroupSPNByObject
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

    foreach ($objectWithSPN in $objectsWithSPN) {
        if ($GroupSPNByObject) {
            $object = [PSCustomObject][ordered]@{
                ServicePrincipalName = $objectWithSPN.ServicePrincipalName -join '|'
                Name                 = $objectWithSPN.Name
                SamAccountName       = $objectWithSPN.SamAccountName
                DistinguishedName    = $objectWithSPN.distinguishedName
                ObjectCategory       = $objectWithSPN.ObjectCategory
                AdminCount           = if ($objectWithSPN.adminCount -ne 1) { 'null' }else { $objectWithSPN.admincount }
            }

            $SPNObjects.Add($object) 
        }
        else {
            if ($objectWithSPN.ServicePrincipalName -gt 1) {
                foreach ($spn in $objectWithSPN.ServicePrincipalName) {
                    $object = [PSCustomObject][ordered]@{
                        ServicePrincipalName = $spn
                        Name                 = $objectWithSPN.Name
                        SamAccountName       = $objectWithSPN.SamAccountName
                        DistinguishedName    = $objectWithSPN.distinguishedName
                        ObjectCategory       = $objectWithSPN.ObjectCategory
                        AdminCount           = if ($objectWithSPN.adminCount -ne 1) { 'null' }else { $objectWithSPN.admincount }
                    }

                    $SPNObjects.Add($object) 
                }
            }
            else {
                $object = [PSCustomObject][ordered]@{
                    ServicePrincipalName = $objectWithSPN.ServicePrincipalName
                    Name                 = $objectWithSPN.Name
                    SamAccountName       = $objectWithSPN.SamAccountName
                    DistinguishedName    = $objectWithSPN.distinguishedName
                    ObjectCategory       = $objectWithSPN.ObjectCategory
                    AdminCount           = if ($objectWithSPN.adminCount -ne 1) { 'null' }else { $objectWithSPN.admincount }
                }

                $SPNObjects.Add($object) 
            }
        }
    }

    return $SPNObjects
}