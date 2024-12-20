$adObjects = Get-ADObject -LDAPFilter '(&(!(adminCount=1))(|(ObjectClass=user)(ObjectClass=Computer)))' -SearchBase (Get-ADRootDSE).defaultNamingContext -Properties DistinguishedName, nTSecurityDescriptor | Where-Object { $_.nTSecurityDescriptor.AreAccessRulesProtected }

[System.Collections.Generic.List[PSObject]]$adobjectWithInheritanceDisabled = @()

foreach ($adObject in $adObjects) {
    $adobjectWithInheritanceDisabled.Add($adObject)
}

if ($adobjectWithInheritanceDisabled) {
    Write-Host -ForegroundColor Yellow "In this forest, found $(($adobjectWithInheritanceDisabled | Measure-Object).count) object(s) that are no longer a member of a group protected by AdminSDHolder AND adminCount is not 1, but still has  inheritance disabled."
    Write-Host -ForegroundColor Yellow "To re-enable inheritance and remove AdminAccount you can use https://l.itpro.tips/resetadmincount"
    Write-Host -ForegroundColor Yellow "Please review the following objects carefully to identify if you need to re-enable inheritance and remove AdminAccount:"

    return $adobjectWithInheritanceDisabled.DistinguishedName
}
else {
    Write-Host -ForegroundColor Green 'Found 0 Objects with Stale Admin Count'
}