#  with this script, Azure AD user returned as a Group, don't know why
function Get-LocalGroupMembersWithAccountManagement {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$GroupName
    )

    [System.Collections.Generic.List[PSObject]]$groupMembersArray = @()
    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    $contextType = [System.DirectoryServices.AccountManagement.ContextType]::Machine
    $principalContext = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList $contextType

    $groupPrincipal = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($principalContext, $groupName)

    if ($null -ne $groupPrincipal) {
        $groupMembers = $groupPrincipal.GetMembers($true)
    
        foreach ($member in $groupMembers) {
            $object = [PSCustomObject][ordered]@{
                Computername      = $Computer
                GroupName         = $groupName
                GroupDescription  = $($localGroup.Description)
                MemberName        = $member.name
                MemberDisplayname = $member.DisplayName
                MemberSid         = $member.SID
                MemberDescription = $member.Description
                MemberType        = if ($member.IsSecurityGroup) { 'Group' } else { 'User' } # with this script, Azure AD user returned as a Group, don't know why
                # PrincipalSource   = $principalSource
            }
        
            $groupMembersArray.Add($object)
        }
    
        $groupPrincipal.Dispose()
    }
    else {
        Write-Host "Group not found: $groupName"
    }

    $principalContext.Dispose()

    return $groupMembersArray
}