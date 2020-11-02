<#
.SYNOPSIS
Get the computers added by regular user in the current domain
.DESCRIPTION
Get the list of computers added by regular user.
By default, each user can join up to 10 computers to an Active Directory domain.
This setting is set in the 'ms-DS-MachineAccountQuota' attribute (https://support.microsoft.com/en-us/help/243327/default-limit-to-number-of-workstations-a-user-can-join-to-the-domain)
If a computer object is added to a domain by an user, the 'ms-DS-CreatorSID' attribute is set with the SID of the creator.
This attribute is not set if the user has Domain Admin permissions or has been delegated the permission to create computers objects.
.OUTPUTS
A PSObject array
 
.NOTES
    Version : 1.01 - August 10 2019
    Author : Bastien Perez - ITPro-Tips (https://itpro-tips.com)
.LINK
https://itpro-tips.com
If you have any problem, any bug, please tell me :
Technet Scriptcenter : https://gallery.technet.microsoft.com/scriptcenter/Get-computers-added-by-0449e96a
Github : https://github.com/itpro-tips/Powershell/blob/master/ActiveDirectory-Toolbox/Get-ComputersAddedByUsers.ps1
#>

Function Get-ComputersAddedByUsers {

    Import-Module ActiveDirectory
    
    $computersAddedByUsers = New-Object System.Collections.ArrayList

    $msDSCreatorsSID = Get-ADComputer -Filter { ms-DS-CreatorSID -like '*' } -Properties ms-DS-CreatorSID, whenCreated | Group-Object ms-DS-CreatorSID 
    
    foreach ($msDSCreatorSID in $msDSCreatorsSID) {
        
        $objUser = $null
        
        # Try to resolve the SID to an account
        try {   
            $objSID = New-Object System.Security.Principal.SecurityIdentifier ($msDSCreatorSID.Name)
            $objUser = $objSID.Translate([System.Security.Principal.NTAccount]).Value
        }
        catch {
            $objUser = 'Unknown (maybe user deleted from AD)'
        }
        
        $outputObject = New-Object PSObject -Property ([Ordered]@{
                ComputerName = ($msDSCreatorSID.Group | Select-Object -ExpandProperty Name) -join '|'
                ComputerDN   = ($msDSCreatorSID.Group | Select-Object -ExpandProperty DistinguishedName) -join '|' 
                ComputerGUID = ($msDSCreatorSID.Group | Select-Object -ExpandProperty ObjectGUID) -join '|' 
                UserDN       = $objUser
                UserSID      = $msDSCreatorSID.Name
                WhenAdded    = ($msDSCreatorSID.Group | Select-Object -ExpandProperty whenCreated) -join '|'				
            })
    
        $null = $computersAddedByUsers.Add($outputObject)
    }

    return $computersAddedByUsers
}