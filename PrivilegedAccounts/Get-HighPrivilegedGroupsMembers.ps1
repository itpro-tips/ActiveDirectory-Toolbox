[System.Collections.Generic.List[PSObject]] $high = @()

$currentDomainSID = (Get-ADDomain).DomainSID
$highPrivilegedGroups = Get-ADGroup -Filter { adminCount -eq '1' }
$protectedusers = Get-ADGroupMember "$($currentDomainSID.Value)-525"

foreach ($group in $highPrivilegedGroups) {
    $members = Get-ADGroupMember -Identity $group.DistinguishedName -Recursive

    foreach ($member in $members) {
        $directMember = $null
        
        # If user is a direct member of the current group, return $true else $false
        $directMember = (Get-ADGroupMember -Identity $group.DistinguishedName).DistinguishedName -contains $member.DistinguishedName

        if ($member.ObjectClass -eq 'Computer') {
            $member = Get-ADComputer -Identity $member.distinguishedName -Properties *
        }
        elseif ($member.ObjectClass -eq 'User') {
            $member = Get-ADUser -Identity $member.distinguishedName -Properties *
        }
        else {
            Write-Warning "$($member.Objectclass) not known by this script"
        }
    
        $object = [PSCustomObject][ordered]@{
            GroupName                                                                 = $group.Name
            SamAccountName                                                            = $member.SamAccountName
            Enabled                                                                   = if ($member.Enabled) { 'Yes' }else { 'No' }
            Active                                                                    = if ($(Get-Date).AddDays(-90) -lt $member.lastLogonDate ) { 'Yes' }else { 'No' }
            'Pwd never Expired'                                                       = if ($member.PasswordNeverExpires) { 'Yes' }else { 'No' }
            'Locked'                                                                  = if ($member.LockedOut) { 'Yes' }else { 'No' }
            'Smart Card required'                                                     = if ($member.SmartcardLogonRequired) { 'Yes' }else { 'No' }
            'Service account (has SPN attribute used now or in the past for service)' = if ($member.ServicePrincipalName -like '*') { 'Yes' }else { 'No' }
            'Flag Cannot be delegated present'                                        = if ($member.AccountNotDelegated) { 'Yes' }else { 'No' }
            'Creation date'                                                           = $member.whenCreated
            'Last login'                                                              = if ($member.lastLogonDate) { $member.lastLogonDate }else { 'Never' }
            'Password last set'                                                       = $member.PasswordLastSet
            'In Protected Users'                                                      = if ($protectedusers.DistinguishedName -contains $member.DistinguishedName) { 'Yes' }else { 'No' }
            'Distinguished name'                                                      = $member.DistinguishedName
            DirectMember                                                              = $directMember
        }

        $high.Add($object)
    }
}