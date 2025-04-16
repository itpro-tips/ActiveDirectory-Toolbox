<#
.CHANGELOG
# Changelog

[1.1.0] - 2025-03-14
# Added
- Add support for MSAs and gMSAs

[1.0.0] - 2023-xx-xx
# Changes
- Initial version
#>


function Get-HighPrivilegedGroupsMembers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$DomainController,
        [Parameter(Mandatory = $false)]
        [Switch]$ExportCSV
    )

    # exit if Active Directory powershell module does not installed
    try {
        Import-Module ActiveDirectory -ErrorAction Stop
    }
    catch {
        Write-Warning 'ActiveDirectory module not found. Please install it and try again.'
        return
    }

    [System.Collections.Generic.List[PSObject]] $highPrivilegedArray = @()
    $exportFolder = 'c:\temp'

    if (-not $DomainController) {
        # cast an array in case only one DC is found
        $DomainController = @(Get-ADDomainController -Discover).HostName
    }
    
    $currentDomainSID = (Get-ADDomain -Server $DomainController).DomainSID
    $highPrivilegedGroups = Get-ADGroup -Filter { adminCount -eq '1' } -Server $DomainController
    $protectedUsersGroup = Get-ADGroupMember "$($currentDomainSID.Value)-525" -Server $DomainController -Recursive

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
            elseif ($member.ObjectClass -eq 'msDS-ManagedServiceAccount' -or $member.ObjectClass -eq 'msDS-GroupManagedServiceAccount') {
                $member = Get-ADServiceAccount -Identity $member.distinguishedName -Properties * -Server $DomainController
            }
            else {
                Write-Warning "$($member.SamAccountName) with objectclass $($member.Objectclass) not known by this script"
            }

            $object = [PSCustomObject][ordered]@{
                GroupName                          = $group.Name
                GroupSID                           = [string]$group.SID
                SamAccountName                     = $member.SamAccountName
                Enabled                            = if ($member.Enabled) { $true } else { $false }
                'Active[Last90Days]'               = if ($(Get-Date).AddDays(-90) -lt $member.lastLogonDate ) { $true } else { $false }
                'Pwd never Expired'                = if ($member.PasswordNeverExpires) { $true } else { $false }
                'Locked'                           = if ($member.LockedOut) { $true } else { $false }
                'Smart Card required'              = if ($member.SmartcardLogonRequired) { $true } else { $false }
                'User kerboastable'                = if ($member.ServicePrincipalName -and $member.ObjectClass -eq 'User') { $true } else { $false }
                'ServicePrincipalNames'            = $member.ServicePrincipalName -join '|'
                'Flag Cannot be delegated present' = if ($member.AccountNotDelegated) { $true } else { $false }
                'Creation date'                    = $member.whenCreated
                'Last login'                       = if ($member.lastLogonDate) { $member.lastLogonDate } else { 'Never' }
                'Password last set'                = $member.PasswordLastSet
                'In Protected Users'               = if ($protectedUsersGroup.DistinguishedName -contains $member.DistinguishedName) { $true } else { $false }
                'Distinguished name'               = $member.DistinguishedName
                DirectMember                       = $directMember
                ObjectClass                        = $member.ObjectClass
                OperatingSystem                    = if ($member.OperatingSystem) { $member.OperatingSystem } else { '-' }
            }

            $highPrivilegedArray.Add($object)
        }
    }

    if ($ExportCSV) {
        $now = (Get-Date).ToString('yyyyMMdd')
    
        if (-not(Test-Path $exportFolder)) {
            try {
                $null = New-Item -Path $exportFolder -ItemType Directory
            }
            catch {
                Write-Warning "Could not create exportFolder $exportFolder. $($_.Exception.Message)"
                return
            }
        }

        $csvFilePath = "$exportFolder\$now-HighPrivilegedGroupsMembers.csv"
        $highPrivilegedArray | Export-Csv -Path $csvFilePath -NoTypeInformation -Encoding UTF8

        Write-Host "Exported to $csvFilePath"
    }
    else {
        return $highPrivilegedArray
    }
}