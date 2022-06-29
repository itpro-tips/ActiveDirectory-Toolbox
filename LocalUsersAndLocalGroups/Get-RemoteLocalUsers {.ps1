function Get-RemoteLocalUsers {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String[]]$ComputerName
    )
    
    [System.Collections.Generic.List[PSObject]]$remoteLocalUsersArray = @()

    foreach ($computer in $computerName) {
    
        $adsi = [ADSI]"WinNT://$Computer,computer"

        $localUsers = $adsi.psbase.Children | Where-Object { $_.psbase.schemaclassname -match 'user' }

        foreach ($localUser in $localUsers) {
            $object = [PSCustomObject][ordered]@{
                Computer                   = $Computer
                Name                       = $($localUser.Name)
                AutoUnlockInterval         = $($localUser.AutoUnlockIntervalToString)
                BadPasswordAttempts        = $($localUser.BadPasswordAttempts)
                Description                = $($localUser.Description)
                FullName                   = $($localUser.FullName)
                HomeDirDrive               = $($localUser.HomeDirDrive)
                HomeDirectory              = $($localUser.HomeDirectory)
                LastLogin                  = $($localUser.LastLogin)
                LockoutObservationInterval = $($localUser.LockoutObservationInterval)
                LoginHours                 = $($localUser.LoginHours)
                LoginScript                = $($localUser.LoginScript)
                MaxBadPasswordsAllowed     = $($localUser.MaxBadPasswordsAllowed)
                MaxPasswordAge             = $($localUser.MaxPasswordAge)
                MaxStorage                 = $($localUser.MaxStorage)
                MinPasswordAge             = $($localUser.MinPasswordAge)
                MinPasswordLength          = $($localUser.MinPasswordLength)
                ObjectSid                  = $((New-Object System.Security.Principal.SecurityIdentifier($($localUser.ObjectSID), 0))).Value
                Parameters                 = $($localUser.Parameters)
                PasswordAge                = $($localUser.PasswordAge)
                PasswordExpired            = $($localUser.PasswordExpired)
                PasswordHistoryLength      = $($localUser.PasswordHistoryLength)
                PrimaryGroupID             = $($localUser.PrimaryGroupID)
                Profile                    = $($localUser.Profile)
                UserFlags                  = $($localUser.UserFlags)
            }

            $remoteLocalUsersArray.Add($object)
        }
    }

    return $remoteLocalUsersArray
}