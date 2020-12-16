<#
.SYNOPSIS
Get the computers added by regular user in the current domain
.DESCRIPTION
Get the list of computers added by regular user.
By default, each user can join up to 10 computers to an Active Directory domain.
This setting is set in the 'ms-DS-MachineAccountQuota' attribute (https://support.microsoft.com/en-us/help/243327/default-limit-to-number-of-workstations-a-user-can-join-to-the-domain)
If a computer object is added to a domain by a regular user, the 'ms-DS-CreatorSID' attribute is set with the SID of the creator.
This attribute is not set if the user has Domain Admin permissions or has been delegated the permission to create computers objects at the computers creation time.

.OUTPUTS
A System.Collections.ArrayList with all computrs added by non admin users
 
.NOTES
    Version : 1.02 - September 2020
    Author : Bastien Perez - ITPro-Tips (https://itpro-tips.com)
.LINK
https://itpro-tips.com
If you have any problem, any bug, please tell me.
Github : https://github.com/itpro-tips/ActiveDirectory-Toolbox/blob/master/Computers/Get-ComputersAddedByUsers.ps1
#>

Function Get-ComputersAddedByUsers {

    Import-Module ActiveDirectory

    $ComputersAddedByUsers = New-Object -TypeName "System.Collections.ArrayList"

    Write-Host 'Search objects with Filter ms-DS-CreatorSID=*' -ForegroundColor Cyan
    try {
        $computersFound = Get-ADObject -LDAPFilter 'ms-DS-CreatorSID=*' -Properties ms-DS-CreatorSID, WhenCreated
    }
    catch {
        Write-Warning "$_.Exception.Message"
        exit
    }

    foreach ($computerFound in $computersFound) {
    
        $objUser = $null
        
        # Try to resolve the SID into an account
        try {
            $objSID = New-Object System.Security.Principal.SecurityIdentifier ($computerFound.'ms-DS-CreatorSID')
            $objUser = $objSID.Translate([System.Security.Principal.NTAccount])
        }
        catch {
            $objUser = 'Unknown (maybe user deleted from AD)'
        }
            
        $object = New-Object -TypeName PSObject -Property ([ordered] @{
            ComputerName = $computerFound.Name
            ComputerDN   = $computerFound.DistinguishedName
            UserName     = $objUser
            UserSID      = $objSID
            WhenCreated  = $computerFound.WhenCreated
        })

        $null = $ComputersAddedByUsers.Add($object)
    }

    return $ComputersAddedByUsers
}