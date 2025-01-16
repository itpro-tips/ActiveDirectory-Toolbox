# Custom function instead of Get-LocalGroupMember because it's not working if member has unresolved SID
# Get-LocalGroupMember PowerShell command doesn’t work on an Microsoft Entra ID joined device as there are two unresolved SIDs in the member list. 
# It will throw the following error: Failed to compare two elements in the array.
# Issue #2996 · PowerShell/PowerShell · GitHub
function Get-LocalGroupMembersWithWinNT {
    Param(
        [Parameter(Mandatory = $True, Position = 1)]
        [string]$GroupName,
        [string]$Computer = $env:COMPUTERNAME
    )
 
    [System.Collections.Generic.List[PSObject]]$groupMembersArray = @()

    $ADSIComputer = [ADSI]("WinNT://$Computer,computer")
    $group = $ADSIComputer.psbase.children.find("$GroupName", 'Group')
 
    $group.psbase.invoke('members') | ForEach-Object {
        $path = $null

        $path = $_.GetType().InvokeMember('ADsPath', 'GetProperty', $null, $_, $null)

        if (($path -like "*/$computer/*") -Or ($path -like 'WinNT://NT*')) {
            $principalSource = 'Local'
        }
        elseif ($path -like 'WinNT://AzureAD/*') {
            $principalSource = 'EntraID'
        }
        elseif ($path -like 'WinNT://S-1-5-21-*') {
            $principalSource = 'ActiveDirectory (unable to resolve SID because former user/group)'
        }
        elseif ($path -like 'WinNT://S-1-12-1-*') {
            $principalSource = 'EntraID (unable to resolve SID)'
        }
        else {
            $principalSource = 'ActiveDirectory'
        }

        $memberType = $null
        $memberName = $null
        $memberSID = $null
        $memberStatus = 'UnknownOrNotApplicable'
        
        $memberType = $_.GetType().InvokeMember('Class', 'GetProperty', $null, $_, $null)
        $memberName = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
        $memberSID = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $_.GetType().InvokeMember('ObjectSID', 'GetProperty', $null, $_, $null), 0

        if ($memberType -eq 'User' -and $principalSource -eq 'Local') {
            # return $true if the account is disabled
            $memberStatus = -not ($_.GetType().InvokeMember('AccountDisabled', 'GetProperty', $null, $_, $null))
        }
        
        $object = [PSCustomObject][ordered]@{
            Computername          = $Computer
            GroupName             = $groupName
            MemberName            = $memberName
            MemberEnabled         = $memberStatus
            MemberPath            = $path
            MemberSid             = $memberSID
            MemberType            = $memberType
            MemberPrincipalSource = $principalSource
        }

        $groupMembersArray.Add($object)
    }
 
    return $groupMembersArray
}