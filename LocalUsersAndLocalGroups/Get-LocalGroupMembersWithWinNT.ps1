# Custom function instead of Get-LocalGroupMember because it's not working if member has unresolved SID
# Get-LocalGroupMember PowerShell command doesn’t work on an Microosft Entra ID joined device as there are two unresolved SIDs in the member list. 
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

        $path = $_.GetType().InvokeMember('ADsPath', "GetProperty", $null, $_, $null)

        if (($path -like "*/$computer/*") -Or ($path -like "WinNT://NT*")) {
            $principalSource = 'Local'
        }
        elseif ($path -like 'WinNT://AzureAD/*') {
            $principalSource = 'AzureAD'
        }
        elseif ($path -like 'WinNT://S-1*') {
            $principalSource = 'Problably AzureAD'
        }
        else {
            $principalSource = 'ActiveDirectory'
        }

        $object = [PSCustomObject][ordered]@{
            Computername          = $Computer
            GroupName             = $groupName
            #GroupDescription  = $($localGroup.Description)
            MemberName            = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
            MemberPath            = $path
            #MemberDisplayname = $_.GetType().InvokeMember("DisplayName", 'GetProperty', $null, $_, $null)
            MemberSid             = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $_.GetType().InvokeMember("ObjectSID", 'GetProperty', $null, $_, $null), 0
            #MemberDescription        = $_.GetType().InvokeMember("Description", 'GetProperty', $null, $_, $null)
            MemberType            = $_.GetType().InvokeMember('Class', 'GetProperty', $null, $_, $null)
            MemberPrincipalSource = $principalSource
        }
        $groupMembersArray.Add($object)
    }
 
    return $groupMembersArray
}