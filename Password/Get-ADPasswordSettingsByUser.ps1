Function Get-ADPasswordSettingsByUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string[]]$SamAccountName,
        [Parameter(Mandatory = $false)]
        [string]$DomainController
    )
    Import-Module ActiveDirectory
    
    [System.Collections.Generic.List[PSObject]]$passwordSettingsByUser = @()
    
    #$defautPasswordPolicyObject = (Get-GPInheritance -Target (Get-ADDomain).DistinguishedName).inheritedGpoLinks | Select-Object -First 1
    if (-not $DomainController) {
        # choose PDC emulator
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
        $DomainController = $domain.PdcRoleOwner.Name
    }

    $defautPasswordPolicyObject = Get-ADDefaultDomainPasswordPolicy -Server $DomainController
    $defautPasswordPolicyDays = $defautPasswordPolicyObject.MaxPasswordAge.Days
    
    if ($SamAccountName) {
        [System.Collections.Generic.List[PSObject]]$Users = @()

        foreach ($sam in $SamAccountName) {
            try {
                $u = Get-ADUser -Identity $sam -Properties DisplayName, msDS-UserPasswordExpiryTimeComputed, PasswordNeverExpires, pwdLastSet, Enabled, badPwdCount, badPasswordTime, LastLogonDate -ErrorAction Stop -Server $DomainController
            
                $users.Add($u)
            }
            catch {
                Write-Warning "$($_.Exception.Message)"
                return
            }
        }
    }
    else {
        try {
            $users = Get-ADUser -Filter * -Properties DisplayName, msDS-UserPasswordExpiryTimeComputed, PasswordNeverExpires, pwdLastSet, Enabled, badPwdCount, badPasswordTime, LastLogonDate -ErrorAction Stop -Server $DomainController
        }
        catch {
            Write-Warning "$($_.Exception.Message)"
            return
        }
    }
    
    foreach ($user in $users) {
        $passwordPolicyMaxPasswordAge = $null

        $fineGrainedPassword = Get-ADUserResultantPasswordPolicy -Identity $user.SamAccountName -Server $DomainController
        
        switch ($fineGrainedPassword.Name) {
            $null {
                $policy = 'GPO or domain settings'
                $passwordPolicyMaxPasswordAge = $defautPasswordPolicyDays
                $lockoutDuration = $defautPasswordPolicyObject.LockoutDuration
                $lockoutObservationWindow = $defautPasswordPolicyObject.LockoutObservationWindow
                $lockoutThreshold = $defautPasswordPolicyObject.LockoutThreshold
                break
            }
            default {
                $policy = $fineGrainedPassword.Name + " (Fine Grained Password)"
                $passwordPolicyMaxPasswordAge = $fineGrainedPassword.MaxPasswordAge.Days
                $lockoutDuration = $fineGrainedPassword.LockoutDuration
                $lockoutObservationWindow = $fineGrainedPassword.LockoutObservationWindow
                $lockoutThreshold = $fineGrainedPassword.LockoutThreshold
                break
            }
        }
        
        if ($user.pwdLastSet -eq 0) {
            $pwdLastSet = 'Never'
        }
        else {
            $pwdLastSet = $([datetime]::FromFileTime($user.pwdLastSet).ToUniversalTime())
        }
    
        if ($user.'msDS-UserPasswordExpiryTimeComputed' -eq 9223372036854775807 -and $user.PasswordNeverExpires -eq $false) {
            $expirationDate = "Never (no password policy in GPO or never set)"
            $daysLeft = '-'
        }
        elseif ($user.PasswordNeverExpires -and $user.'msDS-UserPasswordExpiryTimeComputed' -ne 0) {
            $expirationDate = "Never (configured as 'Never expires')"
            $daysLeft = '-'
            
        }
        elseif ($user.'msDS-UserPasswordExpiryTimeComputed' -eq 0) {
            if ($defautPasswordPolicyDays -eq 0) {
                $expirationDate = 'Never (no password policy in GPO)'
            }
            else {
                $expirationDate = "Password is set to be changed at 'next logon' so no way to calculate the password expiration date"
            }
            $daysLeft = '-'
        }
        else {
            $expirationDate = $([datetime]::FromFileTime($user.'msDS-UserPasswordExpiryTimeComputed').ToUniversalTime())
            $daysLeft = New-TimeSpan (Get-Date).ToUniversalTime() $expirationDate
            
            if ($daysLeft -le 0 -and $null -ne $daysLeft) {
                $daysLeft = 'Already expired'
            }
            else {
                $daysLeft = $daysLeft.Days
            }
        }
    
        $object = [PSCustomObject][ordered]@{
            Identity                                                   = $user.SamAccountName
            DisplayName                                                = $user.DisplayName
            Enabled                                                    = $user.Enabled
            DistinguishedName                                          = $user.DistinguishedName
            PasswordPolicy                                             = $policy
            PasswordPolicyMaxPasswordAge                               = if ($passwordPolicyMaxPasswordAge -eq 0) { 'No Expiration' }else { $passwordPolicyMaxPasswordAge }
            'PasswordLastSet (UTC Time)'                               = $pwdLastSet
            'PasswordExpirationDate (UTC Time)'                        = $expirationDate
            'Days left before password change (according to UTC Time)' = $daysLeft
            LockoutDuration                                            = $lockoutDuration
            LockoutObservationWindow                                   = $lockoutDuration
            LockoutThreshold                                           = $lockoutThreshold
            LastLogonDate                                              = if ($user.LastLogonDate) { $user.LastLogonDate }else { 'Never logged in' }
            BadPwdCount                                                = $user.BadPwdCount
            BadPasswordTime                                            = [datetime]::FromFileTimeUTC($user.BadPasswordTime) # is integer, convert to datetime
            FromDomainController                                       = $DomainController
        }
    
        $passwordSettingsByUser.add($object)
    }
    
    $passwordSettingsByUser | Sort-Object PasswordExpirationDate* -Descending
}