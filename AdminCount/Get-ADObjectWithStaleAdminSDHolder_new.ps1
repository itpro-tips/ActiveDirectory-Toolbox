function Get-ADObjectWithStaleAdminSDHolder {

    [System.Collections.Generic.List[PSObject]]$objectsWithStaleAdminAccount = @()
    [System.Collections.Generic.List[PSObject]]$objectsWithAdminCount = @()
    [System.Collections.Generic.List[PSObject]]$legitimateObjectsWithAdminCount = @()

    <#
groups protected by AdminSDHolder
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
    
    foreach ($domain in (Get-ADForest).domains) {

        $currentDomainSID = (Get-ADDomain -Identity $domain).DomainSID

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
            'Domain Admins'                = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountDomainAdminsSid, $currentDomainSID))
            # Domain Controllers "$currentDomainSID-516"
            'Domain Controllers'           = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountControllersSid, $currentDomainSID))
            # Enterprise Admins "$currentDomainSID-519"
            'Enterprise Admins'            = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountEnterpriseAdminsSid, $currentDomainSID))
            # Schema Admins "$currentDomainSID-518"
            'Schema Admins'                = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::AccountSchemaAdminsSid, $currentDomainSID))
            # Print Operators 'S-1-5-32-550'
            'Print Operators'              = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinPrintOperatorsSid, $null))
            #Read-only Domain Controllers "$currentDomainSID-521"
            # get SID don't work , so we use xx-521 Read-only Domain Controllers' = [string] (New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::WinEnterpriseReadonlyControllersSid, $currentDomainSID))
            'Read-only Domain Controllers' = "$currentDomainSID-521"
        }
    
        foreach ($defaultGroup in $defaultProtectedGroupsSID.GetEnumerator()) {
            $group = Get-ADGroup -LDAPFilter "(objectSID=$($defaultGroup.Value))" -Server $domain | Select-Object Name, DistinguishedName, @{Name = 'Domain'; Expression = { $domain } }

            # test group exist because some group exist only in parent domain
            if ($group) {
                # get all recursive members of the group
                Get-ADGroupMember -Identity $group.DistinguishedName -Recursive -Server $domain | ForEach-Object {
                    $object = [PSCustomObject][ordered]@{
                        Group    = $group.Name
                        MemberDN = $_.DistinguishedName
                    }

                    $legitimateObjectsWithAdminCount.Add($object)
                }

            }
            
            
            # not useful but keep it for now
            # $defaultProtectedGroups.Add($group)
        }

        Get-ADObject -Filter 'admincount -eq 1 -and (iscriticalsystemobject -ne $TRUE -or iscriticalsystemobject -notlike "*")' -Server "$domain" -Properties whenchanged, whencreated, admincount, 'msDS-ReplAttributeMetaData', samaccountname, userAccountControl | ForEach-Object {
            $ftimeLastOriginatingChange = $null
            $ftimeLastOriginatingChange = (($_.'msDS-ReplAttributeMetaData' | ForEach-Object { ([XML]$_.Replace("`0", "")).DS_REPL_ATTR_META_DATA | Where-Object { $_.pszAttributeName -eq "admincount" } }).ftimeLastOriginatingChange | Get-Date -Format MM/dd/yyyy)
            
            $object = [PSCustomObject][ordered]@{
                Domain            = "$domain"
                DistinguishedName = $_.DistinguishedName
                whenChanged       = $_.whenChanged
                whenCreated       = $_.whenCreated
                adminCount        = $_.adminCount
                SamAccountName    = $_.SamAccountName
                ObjectClass       = $_.ObjectClass
                # adminCountDate is the date the admincount attribute was last set to 1 - we need to use the msDS-ReplAttributeMetaData attribute to determine the date the admincount attribute was last set to 1
                adminCountDate    = $ftimeLastOriginatingChange
                #adminCountDate    = if ($_.'msDS-ReplAttributeMetaData') { ($_.'msDS-ReplAttributeMetaData' | Where-Object { $_.pszAttributeName -eq 'adminCount' }).ftimeLastOriginatingChange | Get-Date -Format MM/dd/yyyy } else { $null }
                # Enabled attribute is not an AD attribute (only calculate with Get-ADUser/Computer, so it does not exist with Get-ADObject, so we need to parse the userAccountControl attribute to determine if the account is enabled or not with [bool]($_.userAccountControl -band 2)
                Enabled           = -not [bool]($_.userAccountControl -band 2)
            }

            $objectsWithAdminCount.Add($object)
        }
    }

    # get AD objects that are not member of a group protected by adminSDHolder
    $objectsWithStaleAdminAccount = $objectsWithAdminCount | Where-Object { $_.DistinguishedName -notin $legitimateObjectsWithAdminCount.MemberDN }

    if ($objectsWithStaleAdminAccount) {
        Write-Host -ForegroundColor Yellow "In this forest, found $(($objectsWithStaleAdminAccount | Measure-Object).count) object(s) that are no longer a member of a group protected by AdminSDHolder but still has admincount attribute set to 1 inheritance disabled."
        Write-Host -ForegroundColor Yellow "To re-enable inheritance and remove AdminAccount you can use https://l.itpro.tips/resetadmincount"
    }
    else {
        Write-Host -ForegroundColor Green 'in this AD forest, found 0 Objects with Stale Admin Count'
    }

    return $objectsWithStaleAdminAccount
}