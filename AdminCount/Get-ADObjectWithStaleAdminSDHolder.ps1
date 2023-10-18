function Get-ADObjectWithStaleAdminSDHolder {

    [System.Collections.Generic.List[PSObject]]$OrphanResults = @()
    [System.Collections.Generic.List[PSObject]]$NonOrphanResults = @()
    [System.Collections.Generic.List[PSObject]]$results = @()
    [System.Collections.Generic.List[PSObject]]$objectsProtectedByAdminSDHolder = @()

    Get-ADObject -Filter 'admincount -eq 1 -and (iscriticalsystemobject -ne $TRUE -or iscriticalsystemobject -notlike "*")' `
        -Properties whenchanged, whencreated, admincount, isCriticalSystemObject, "msDS-ReplAttributeMetaData", samaccountname | ForEach-Object {
        $object = [PSCustomObject]@{
            distinguishedname      = $_.distinguishedname
            whenchanged            = $_.whenchanged
            whencreated            = $_.whencreated
            admincount             = $_.admincount
            SamAccountName         = $_.SamAccountName
            objectclass            = $_.objectclass
            isCriticalSystemObject = $_.isCriticalSystemObject
            adminCountDate         = ($_.msDSReplAttributeMetaData | Where-Object { $_.pszAttributeName -eq 'admincount' }).ftimeLastOriginatingChange | Get-Date -Format MM/dd/yyyy
        }

        $objectsProtectedByAdminSDHolder.Add($object)
    }

    $defaultAdminGroups = Get-ADGroup -Filter 'admincount -eq 1 -and iscriticalsystemobject -like "*"' | Select-Object distinguishedname

    foreach ($objectProtected in $objectProtectedByAdminSDHolder) {
        $objectDN = ($objectProtected).Distinguishedname
        foreach ($Group in $DefaultAdminGroups) {
            $object = [PSCustomObject]@{
                GroupDistinguishedname = $Group.distinguishedname
                Member                 = if (Get-ADgroup -Filter { member -RecursiveMatch $objectDN } -searchbase $Group.distinguishedname) { $True } else { $False }
                distinguishedname      = $Object.distinguishedname
                admincount             = $Object.admincount
                adminCountDate         = $Object.adminCountDate
                whencreated            = $Object.whencreated
                objectclass            = $Object.objectclass
            }

            $results.Add($object)
        }

        if ($Results | Where-Object { $_.member }) {
            $NonOrphanResults.Add($($Results | Where-Object { $_.member }))
        }
        else {
            $OrphanResults.Add($($Results  | Select-Object objectclass, admincount, adminCountDate, distinguishedname | Get-Unique))
        }
    }

    if ($OrphanResults) {
        "Found $(($OrphanResults | Measure-Object).count) user object that are no longer a member of a priviledged group but still has admincount attribute set to 1 and inheritance disabled"
    }
    else {
        'Found 0 Objects with Stale Admin Count'
    }

    return $OrphanResults
}