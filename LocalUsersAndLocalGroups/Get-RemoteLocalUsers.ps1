function Get-RemoteLocalUsers {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$ComputerName
    )
    
    [System.Collections.Generic.List[PSObject]]$remoteLocalUsersArray = @()

    foreach ($computer in $computerName) {
        
        if ($computer -eq 'localhost') {
            $computer = $env:COMPUTERNAME
        }

        $adsi = [ADSI]"WinNT://$computer,computer"

        try {
            # Test ADSI
            [void]$adsi.Tostring()
        }
        catch {
            $object = [PSCustomObject][ordered]@{
                Computername               = $computer
                Name                       = $_.Exception.Message
                AutoUnlockInterval         = $_.Exception.Message
                BadPasswordAttempts        = $_.Exception.Message
                Description                = $_.Exception.Message
                FullName                   = $_.Exception.Message
                HomeDirDrive               = $_.Exception.Message
                HomeDirectory              = $_.Exception.Message
                LastLogin                  = $_.Exception.Message
                LockoutObservationInterval = $_.Exception.Message
                LoginHours                 = $_.Exception.Message
                LoginScript                = $_.Exception.Message
                MaxBadPasswordsAllowed     = $_.Exception.Message
                MaxPasswordAge             = $_.Exception.Message
                MaxStorage                 = $_.Exception.Message
                MinPasswordAge             = $_.Exception.Message
                MinPasswordLength          = $_.Exception.Message
                ObjectSid                  = $_.Exception.Message
                Parameters                 = $_.Exception.Message
                PasswordLastSet            = $_.Exception.Message
                PasswordAgeInDays          = $_.Exception.Message
                PasswordExpired            = $_.Exception.Message
                PasswordHistoryLength      = $_.Exception.Message
                PrimaryGroupID             = $_.Exception.Message
                Profile                    = $_.Exception.Message
                UserFlags                  = $_.Exception.Message
            }

            $remoteLocalUsersArray.Add($object)

            continue
        }

        $localUsers = $adsi.psbase.Children | Where-Object { $_.psbase.schemaclassname -match 'user' }

        foreach ($localUser in $localUsers) {
            $object = [PSCustomObject][ordered]@{
                Computer                   = $computer
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
                PasswordLastSet            = (Get-Date).AddSeconds( - [int]($($localUser.PasswordAge)))
                PasswordAgeInDays          = $($localUser.PasswordAge) / 86400
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