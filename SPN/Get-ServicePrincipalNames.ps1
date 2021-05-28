#Gets all the SPNS in the domain
 
# Alternative way to get the same information using CMD.exe:
# dsquery * "DC=yourdomain,DC=com" -filter "(&(objectcategory=computer)(servicePrincipalName=*))" -attr distinguishedName servicePrincipalName > spns.txt

#$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
 
#$search.filter = "(servicePrincipalName=*)"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=person))"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=user))"
#$results = $search.Findall()

Get-ADObject -LDAPFilter "(servicePrincipalName=*)"

$SPNObjects = New-Object 'System.Collections.Generic.List[System.Object]'


foreach ($result in $results) {
      
    $userEntry = $result.GetDirectoryEntry()
    $outputObject = New-Object PSObject -Property ([ordered]@{
            Name              = $userEntry.name
            DistinguishedName = $userEntry.distinguishedName
            UserPrincipalName = $userEntry.servicePrincipalName -join '|'
            ObjectCategory    = $userEntry.objectCategory
        })
    $null = $SPNObjects.Add($outputObject) 
}

return $SPNObjects