#Gets all the SPNS in the domain
 
# Alternative way to get the same information using CMD.exe:
# dsquery * "DC=yourdomain,DC=com" -filter "(&(objectcategory=computer)(servicePrincipalName=*))" -attr distinguishedName servicePrincipalName > spns.txt

#$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
 
#$search.filter = "(servicePrincipalName=*)"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=person))"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=user))"
#$results = $search.Findall()

function Get-ServicePrincipalNames {
    $usersWithSPN = Get-ADObject -LDAPFilter "(&(servicePrincipalName=*)(objectCategory=user))" -Properties UserPrincipalName, ObjectCategory, SamAccountName, ServicePrincipalName, AdminCount

    $SPNObjects = New-Object 'System.Collections.Generic.List[System.Object]'


    foreach ($userWithSPN in $usersWithSPN) {
        $object = New-Object PSObject -Property ([ordered]@{
                Name                 = $userWithSPN.Name
                SamAccountName       = $userWithSPN.SamAccountName
                DistinguishedName    = $userWithSPN.distinguishedName
                ServicePrincipalName = $userWithSPN.ServicePrincipalName -join '|'
                ObjectCategory       = $userWithSPN.ObjectCategory
                AdminCount           = if ($userWithSPN.adminCount -ne 1) { 'null' }else { $userWithSPN.admincount }
            })
    
        $SPNObjects.Add($object) 
    }

    return $SPNObjects
}