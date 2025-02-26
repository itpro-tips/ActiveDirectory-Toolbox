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
        # lastlogin for the member

        if ($memberType -eq 'User' -and $principalSource -eq 'Local') {
            # return $true if the account is disabled
            $lastLogin = $_.GetType().InvokeMember('LastLogin', 'GetProperty', $null, $_, $null)
            $memberStatus = -not ($_.GetType().InvokeMember('AccountDisabled', 'GetProperty', $null, $_, $null))
            $lockoutObservationInterval = $_.GetType().InvokeMember('LockoutObservationInterval', 'GetProperty', $null, $_, $null)
            $loginHours = $_.GetType().InvokeMember('LoginHours', 'GetProperty', $null, $_, $null)
            $loginScript = $_.GetType().InvokeMember('LoginScript', 'GetProperty', $null, $_, $null)
            $maxBadPasswordsAllowed = $_.GetType().InvokeMember('MaxBadPasswordsAllowed', 'GetProperty', $null, $_, $null)
            $maxPasswordAge = $_.GetType().InvokeMember('MaxPasswordAge', 'GetProperty', $null, $_, $null)
            $maxStorage = $_.GetType().InvokeMember('MaxStorage', 'GetProperty', $null, $_, $null)
            $minPasswordAge = $_.GetType().InvokeMember('MinPasswordAge', 'GetProperty', $null, $_, $null)
            $minPasswordLength = $_.GetType().InvokeMember('MinPasswordLength', 'GetProperty', $null, $_, $null)
            $passwordAge = $_.GetType().InvokeMember('PasswordAge', 'GetProperty', $null, $_, $null)
            $passwordExpired = $_.GetType().InvokeMember('PasswordExpired', 'GetProperty', $null, $_, $null)
            $passwordHistoryLength = $_.GetType().InvokeMember('PasswordHistoryLength', 'GetProperty', $null, $_, $null)
            $primaryGroupID = $_.GetType().InvokeMember('PrimaryGroupID', 'GetProperty', $null, $_, $null)
            $userFlags = $_.GetType().InvokeMember('UserFlags', 'GetProperty', $null, $_, $null)
        }
        else {
            $lastLogin = 'UnknownOrNotApplicable'
            $memberStatus = 'UnknownOrNotApplicable'
            $lockoutObservationInterval = 'UnknownOrNotApplicable'
            $loginHours = 'UnknownOrNotApplicable'
            $loginScript = 'UnknownOrNotApplicable'
            $maxBadPasswordsAllowed = 'UnknownOrNotApplicable'
            $maxPasswordAge = 'UnknownOrNotApplicable'
            $maxStorage = 'UnknownOrNotApplicable'
            $minPasswordAge = 'UnknownOrNotApplicable'
            $minPasswordLength = 'UnknownOrNotApplicable'
            $passwordAge = 'UnknownOrNotApplicable'
            $passwordExpired = 'UnknownOrNotApplicable'
            $passwordHistoryLength = 'UnknownOrNotApplicable'
            $primaryGroupID = 'UnknownOrNotApplicable'
            $userFlags = 'UnknownOrNotApplicable'
        }
        
        $object = [PSCustomObject][ordered]@{
            Computername               = $Computer
            GroupName                  = $groupName
            MemberName                 = $memberName
            MemberEnabled              = $memberStatus
            MemberPath                 = $path
            MemberSid                  = $memberSID
            MemberType                 = $memberType
            MemberPrincipalSource      = $principalSource
            LastLogin                  = $lastLogin
            LockoutObservationInterval = $lockoutObservationInterval
            LoginHours                 = $loginHours
            LoginScript                = $loginScript
            MaxBadPasswordsAllowed     = $maxBadPasswordsAllowed
            MaxPasswordAge             = $maxPasswordAge
            MaxStorage                 = $maxStorage
            MinPasswordAge             = $minPasswordAge
            MinPasswordLength          = $minPasswordLength
            PasswordAge                = $passwordAge
            PasswordExpired            = $passwordExpired
            PasswordHistoryLength      = $passwordHistoryLength
            PrimaryGroupID             = $primaryGroupID
            UserFlags                  = $userFlags
        }

        $groupMembersArray.Add($object)
    }
 
    return $groupMembersArray
}