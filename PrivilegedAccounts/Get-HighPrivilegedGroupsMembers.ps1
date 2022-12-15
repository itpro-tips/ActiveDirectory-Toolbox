[CmdletBinding()]
param (
    [Parameter()]
    [String]$DomainController
)

[System.Collections.Generic.List[PSObject]] $high = @()

if (-not $DomainController) {
    $DomainController = (Get-ADDomainController -Discover).HostName
}
    
$currentDomainSID = (Get-ADDomain -Server $DomainController).DomainSID
$highPrivilegedGroups = Get-ADGroup -Filter { adminCount -eq '1' } -Server $DomainController
$protectedusers = Get-ADGroupMember "$($currentDomainSID.Value)-525" -Server $DomainController

foreach ($group in $highPrivilegedGroups) {
    $members = Get-ADGroupMember -Identity $group.DistinguishedName -Recursive -Server $DomainController

    foreach ($member in $members) {
        $directMember = $null
        
        # If user is a direct member of the current group, return $true else $false
        $directMember = (Get-ADGroupMember -Identity $group.DistinguishedName -Server $DomainController).DistinguishedName -contains $member.DistinguishedName

        if ($member.ObjectClass -eq 'Computer') {
            $member = Get-ADComputer -Identity $member.distinguishedName -Properties * -Server $DomainController
        }
        elseif ($member.ObjectClass -eq 'User') {
            $member = Get-ADUser -Identity $member.distinguishedName -Properties * -Server $DomainController
        }
        else {
            Write-Warning "$($member.Objectclass) not known by this script"
        }
    
        $object = [PSCustomObject][ordered]@{
            GroupName                                                                 = $group.Name
            SamAccountName                                                            = $member.SamAccountName
            Enabled                                                                   = if ($member.Enabled) { $true } else { $false }
            Active                                                                    = if ($(Get-Date).AddDays(-90) -lt $member.lastLogonDate ) { $true } else { $false }
            'Pwd never Expired'                                                       = if ($member.PasswordNeverExpires) { $true } else { $false }
            'Locked'                                                                  = if ($member.LockedOut) { $true } else { $false }
            'Smart Card required'                                                     = if ($member.SmartcardLogonRequired) { $true } else { $false }
            'Service account (has SPN attribute used now or in the past for service)' = if ($member.ServicePrincipalName -like '*') { $true } else { $false }
            'Flag Cannot be delegated present'                                        = if ($member.AccountNotDelegated) { $true } else { $false }
            'Creation date'                                                           = $member.whenCreated
            'Last login'                                                              = if ($member.lastLogonDate) { $member.lastLogonDate } else { 'Never' }
            'Password last set'                                                       = $member.PasswordLastSet
            'In Protected Users'                                                      = if ($protectedusers.DistinguishedName -contains $member.DistinguishedName) { $true } else { $false }
            'Distinguished name'                                                      = $member.DistinguishedName
            DirectMember                                                              = $directMember
            ObjectClass                                                               = $member.ObjectClass
            OperatingSystem                                                           = if ($member.OperatingSystem) { $member.OperatingSystem } else { '-' }
        }

        $high.Add($object)
    }
}

return $high