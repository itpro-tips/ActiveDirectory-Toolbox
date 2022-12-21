# info: # gpLink is a string [LDAP://cn={C408C216-5CEE-4EE7-B8BD-386600DC01EA},cn=policies,cn=system,DC=domain,DC=com;0][LDAP://cn={C408C16-5D5E-4EE7-B8BD-386611DC31EA},cn=policies,cn=system,DC=domain,DC=com;0]

[System.Collections.Generic.List[PSObject]]$adObjects = @()
[System.Collections.Generic.List[PSObject]]$linkedGPO = @()

$rootDSE = Get-ADRootDSE

$gpos = Get-ADObject -LDAPFilter '(objectClass=groupPolicyContainer)' -SearchBase "CN=System,$($rootDSE.defaultNamingcontext)" -Properties displayName | Select-Object DisplayName, @{Name = 'Name'; Expression = { $_.Name.Replace('{', '').Replace('}', '') } }
$domainAndOUS = Get-ADObject -LDAPFilter "(&(|(objectClass=organizationalUnit)(objectClass=domainDNS))(gplink=*))" -SearchBase "$($rootDSE.defaultNamingcontext)" -Properties gpLink
$sites = Get-ADObject -LDAPFilter "(&(objectClass=site)(gplink=*))" -SearchBase "$($rootDSE.configurationNamingContext)" -Properties gpLink

# build list with all objects with gpLink
$adObjects.Add($domainAndOUS)
$adObjects.Add($sites)

foreach ($gpo in $gpos) {
    # Compare if GUID exist in gpLink
    if ($adObjects.gpLink -match $gpo.Name) {
        $linkedGPO.Add($gpo)
    }
}

# cast in array in case only one object
([array]($gpos | Where-Object { $_.DisplayName -notin $linkedGPO.DisplayName })).count

# To get name of unlinked GPO:
#$gpos | Where-Object {$_.DisplayName -notin $linkedGPO.DisplayName}