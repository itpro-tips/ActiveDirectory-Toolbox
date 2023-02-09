$adObjects = Get-ADObject -LDAPFilter '(&(!(adminCount=1))(|(ObjectClass=user)(ObjectClass=Computer)))' -SearchBase (Get-ADRootDSE).defaultNamingContext -Properties *| where {$_.nTSecurityDescriptor.AreAccessRulesProtected}

foreach($adObject in $adObjects){
    Write-Warning "Inheritance disabled $($adObject.DistinguishedName)"
}