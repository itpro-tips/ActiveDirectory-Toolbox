function Get-ADObjectWithStaleAdminSDHolder {

    [System.Collections.Generic.List[PSObject]]$orphanResults = @()
    [System.Collections.Generic.List[PSObject]]$nonOrphanResult = @()
    [System.Collections.Generic.List[PSObject]]$results = @()
    [System.Collections.Generic.List[PSObject]]$objectsProtectedByAdminSDHolder = @()

    <#
    group protected by AdminSDHolder
| Windows Server 2003 RTM | Windows Server 2003 SP1+ | Windows Server 2012-Windows Server 2008 R2-Windows Server 2008 | Windows Server 2016 |
| --- | --- | --- | --- |
| Account Operators | Account Operators | Account Operators | Account Operators |
| Administrator | Administrator | Administrator | Administrator |
| Administrators | Administrators | Administrators | Administrators |
| Backup Operators | Backup Operators | Backup Operators | Backup Operators |
| Cert Publishers |  |  |  |
| Domain Admins | Domain Admins | Domain Admins | Domain Admins |
| Domain Controllers | Domain Controllers | Domain Controllers | Domain Controllers |
| Enterprise Admins | Enterprise Admins | Enterprise Admins | Enterprise Admins |
| Krbtgt | Krbtgt | Krbtgt | Krbtgt |
| Print Operators | Print Operators | Print Operators | Print Operators |
|  |  | Read-only Domain Controllers | Read-only Domain Controllers |
| Replicator | Replicator | Replicator | Replicator |
| Schema Admins | Schema Admins | Schema Admins | Schema Admins |
| Server Operators | Server Operators | Server Operators | Server Operators | 
    #>

    # https://docs.microsoft.com/en-us/windows/security/identity-protection/access-control/security-identifiers
    # https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/plan/security-best-practices/appendix-c--protected-accounts-and-groups-in-active-directory#protected-accounts-and-groups-in-active-directory-by-operating-system
    # https://renenyffenegger.ch/notes/Microsoft/dot-net/namespaces-classes/System/Security/Principal/WellKnownSidType/index
    [System.Collections.Generic.List[PSObject]]$defaultProtectedGroups = @()

    $currentDomainSID = (Get-ADDomain).DomainSID

    $defaultProtectedGroupsSID = [ordered]@{
        # Account Operators 'S-1-5-32-548'
        'Account Operators'            = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAccountOperatorsSid, $null))
        #Administrators 'S-1-5-32-544'
        'Administrators'               = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid, $null))
        # Backup Operators 'S-1-5-32-551'
        'Backup Operators'             = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinBackupOperatorsSid, $null))
        # Replicator 'S-1-5-32-552'
        'Replicator'                   = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinReplicatorSid, $null))
        # Server Operators 'S-1-5-32-549'
        'Server Operators'             = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinSystemOperatorsSid, $null))
        # Domain Admins "$currentDomainSID-512"
        'Domain Admins'                = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountDomainAdminsSid, $CurrentDomainSid))
        # Domain Controllers "$currentDomainSID-516"
        'Domain Controllers'           = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountControllersSid, $CurrentDomainSid))
        # Enterprise Admins "$currentDomainSID-519"
        'Enterprise Admins'            = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountEnterpriseAdminsSid, $CurrentDomainSid))
        # Schema Admins "$currentDomainSID-518"
        'Schema Admins'                = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountSchemaAdminsSid, $CurrentDomainSid))
        # Print Operators 'S-1-5-32-550'
        'Print Operators'              = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinPrintOperatorsSid, $null))
        #Read-only Domain Controllers "$currentDomainSID-521"
        #dontwork : 'Read-only Domain Controllers' = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::WinEnterpriseReadonlyControllersSid, $currentDomainSID))
        'Read-only Domain Controllers' = "$currentDomainSID-521"
    }
    
    foreach ($group in $defaultProtectedGroupsSID.GetEnumerator()) {
        $gr = Get-ADGroup -LDAPFilter "(objectSID=$($group.Value))" -Properties Name

        $defaultProtectedGroups.Add($gr)
    }

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
            adminCountDate         = if ($_.msDSReplAttributeMetaData) { ($_.msDSReplAttributeMetaData | Where-Object { $_.pszAttributeName -eq 'admincount' }).ftimeLastOriginatingChange | Get-Date -Format MM/dd/yyyy }
        }

        $objectsProtectedByAdminSDHolder.Add($object)
    }

    foreach ($objectProtected in $objectsProtectedByAdminSDHolder) {
        $objectDN = ($objectProtected).Distinguishedname

        foreach ($group in $defaultProtectedGroups) {
            $object = [PSCustomObject]@{
                GroupDistinguishedname = $group.distinguishedname
                Member                 = if (Get-ADgroup -Filter { member -RecursiveMatch $objectDN } -SearchBase $group.distinguishedname) { $True } else { $False }
                distinguishedname      = $objectProtected.distinguishedname
                admincount             = $objectProtected.admincount
                adminCountDate         = $objectProtected.adminCountDate
                whencreated            = $objectProtected.whencreated
                objectclass            = $objectProtected.objectclass
            }

            $results.Add($object)
        }
    }

    if ($Results | Where-Object { $_.member }) {
        $nonOrphanResults.Add($($Results | Where-Object { $_.member }))
    }
    else {
        $orphanResults.Add($($Results  | Select-Object objectclass, admincount, adminCountDate, distinguishedname | Get-Unique))
    }
    

    if ($orphanResults) {
        "Found $(($orphanResults | Measure-Object).count) user object that are no longer a member of a priviledged group but still has admincount attribute set to 1 and inheritance disabled"
    }
    else {
        'Found 0 Objects with Stale Admin Count'
    }

    return $orphanResults
}