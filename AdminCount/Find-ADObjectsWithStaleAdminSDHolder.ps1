#users with admincount = 1 but not member of privileged groups
 
Write-Host 'Starting Function ADObjectswithStaleAdminCount' -ForegroundColor Cyan
    
#users with stale admin count
$results = @()
[System.Collections.Generic.List[PSObject]] $orphan_results = @()
[System.Collections.Generic.List[PSObject]] $non_orphan_results = @()

$flagged_object = foreach ($domain in (Get-ADForest).domains) {
    Get-ADObject -Filter 'admincount -eq 1 -and iscriticalsystemobject -notlike "*"' -Server $domain `
        -Properties whenchanged, whencreated, admincount, isCriticalSystemObject, "msDS-ReplAttributeMetaData", samaccountname |`
        Select-Object @{name = 'Domain'; expression = { $domain } }, distinguishedname, whenchanged, whencreated, admincount, `
        SamAccountName, objectclass, isCriticalSystemObject, @{name = 'adminCountDate'; expression = { ($_ | `
                    Select-Object -ExpandProperty "msDS-ReplAttributeMetaData" | ForEach-Object { ([XML]$_.Replace("`0", "")).DS_REPL_ATTR_META_DATA |`
                        Where-Object { $_.pszAttributeName -eq "admincount" } }).ftimeLastOriginatingChange | Get-Date -Format MM/dd/yyyy }
    }
}

$default_admin_groups = foreach ($domain in (Get-ADForest).domains) {
    Get-ADGroup -Filter 'admincount -eq 1 -and iscriticalsystemobject -like "*"'`
        -Server $domain | Select-Object @{name = 'Domain'; expression = { $domain } }, distinguishedname
}

foreach ($object in $flagged_object) {
    $udn = ($object).distinguishedname
    $results = foreach ($group in $default_admin_groups) {
        $object | Select-Object `
        @{Name = "Group_Domain"; Expression = { $group.domain } }, `
        @{Name = "Group_Distinguishedname"; Expression = { $group.distinguishedname } }, `
        @{Name = "Member"; Expression = { if (Get-ADgroup -Filter { member -RecursiveMatch $udn } -searchbase $group.distinguishedname -server $group.domain) { $True }else { $False } } }, `
            domain, distinguishedname, admincount, adminCountDate, whencreated, objectclass
    }
    if ($results | Where-Object { $_.member }) {
        $non_orphan_results.Add($($results | Where-Object { $_.member }))
    }
    else {
        $orphan_results.Add($($results  | Select-Object Domain, objectclass, admincount, adminCountDate, distinguishedname | Get-Unique))
    }
}

if ($orphan_results) {
    Write-Host "Found $(($orphan_results | Measure-Object).count) user object that are no longer a member of a priviledged group but still has admincount attribute set to 1 and inheritance disabled"  -ForegroundColor Cyan
}
else {
    Write-Host 'Found 0 Objects with Stale Admin Count' -ForegroundColor Cyan
}

return $orphan_results