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
A System.Collections.ArrayList with all computers added by regular users (ie. users without built-in Admin permissions).
If you have some tiering in your domain, you will find some computers added by users with tiering permissions, it's not a problem.
 
.NOTES
    Version : 1.1 - August 2023
    Author : Bastien Perez - ITPro-Tips (https://itpro-tips.com)
.LINK
https://itpro-tips.com
If you have any problem, any bug, please tell me.
Github : https://github.com/itpro-tips/ActiveDirectory-Toolbox/blob/master/Computers/Get-ComputersAddedByUsers.ps1
#>

function Get-ComputersAddedByUsers {

    # Import module if get-adobject is not recognized
    if (-not(Get-Command Get-ADObject -ErrorAction SilentlyContinue)) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
        catch {
            Write-Warning "Unable to import ActiveDirectory module : $($_.Exception.Message)"
            return
        }
    }
    

    [System.Collections.Generic.List[PSObject]]$ComputersAddedByUsers = @()

    Write-Host 'Search objects with ms-DS-CreatorSID not empty' -ForegroundColor Cyan

    try {
        $computersFound = Get-ADObject -LDAPFilter 'ms-DS-CreatorSID=*' -Properties ms-DS-CreatorSID, WhenCreated
    }
    catch {
        Write-Warning "$_.Exception.Message"
        return
    }

    foreach ($computerFound in $computersFound) {
    
        $objUser = $null
        
        # Try to resolve the SID into an account
        try {
            $objSID = New-Object System.Security.Principal.SecurityIdentifier ($computerFound.'ms-DS-CreatorSID')
            $objUser = $objSID.Translate([System.Security.Principal.NTAccount])
        }
        catch {
            $objUser = 'Unknown user (maybe user deleted from AD)'
        }
            
        $object = [PSCustomObject][ordered]@{
            ComputerName = $computerFound.Name
            ComputerDN   = $computerFound.DistinguishedName
            UserName     = $objUser
            UserSID      = $objSID
            WhenCreated  = $computerFound.WhenCreated.ToString('yyyyMMdd-hh:mm:ss')
        }

        $ComputersAddedByUsers.Add($object)
    }

    return $ComputersAddedByUsers
}