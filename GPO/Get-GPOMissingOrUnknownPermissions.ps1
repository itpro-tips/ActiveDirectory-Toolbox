Function Get-GPOMissingOrUnknownPermissions {
    $authenticatedUsersSID = "S-1-5-11"
    $authenticatedUsersGroupName = New-Object System.Security.Principal.SecurityIdentifier ($authenticatedUsersSID)
    $authenticatedUsersGroupName = ($authenticatedUsersGroupName.Translate([System.Security.Principal.NTAccount])).Value
  
    $domainComputersSID = [string](Get-ADDomain).DomainSID + '-515'
    $domainComputersSID = New-Object System.Security.Principal.SecurityIdentifier ($domainComputersSID)
    $domainComputersGroupName = ($domainComputersSID.Translate([System.Security.Principal.NTAccount])).Value
  
    $MissingPermissionsGPOArray = New-Object System.Collections.ArrayList
    
    $GPOs = Get-GPO -All
  
    foreach ($GPO in $GPOs) {
        $GPOPermissions = Get-GPPermission -Guid $GPO.Id -All #| Select-Object -ExpandProperty Trustee | Where-Object { $_.SID -eq $AuthenticatedUsersSID }
        
        $readPermission = $false
        $unknownSID = $null
        foreach ($GPOPermission in $GPOPermissions) {
        
            $problem = $null
        
            if ($GPOPermission.Trustee.SidType -eq "Unknown") {
                $unknownSID = $GPOPermission.Trustee.Sid
            }
            # Read in AD instead of Get-GPPermission because Permission returned does not present Read Permission if many permission exist
            $read = ((Get-Acl "AD:\$($GPO.Path)").Access | Where-Object { ($_.IdentityReference -eq "$domainComputersGroupName" -or $_.IdentityReference -eq "$authenticatedUsersGroupName") -and $_.ActiveDirectoryRights -match 'Read' }).AccessControlType
            
            if ($read -eq 'Allow') {
                $readPermission = $true
            }
        }
  
        if (-not $readPermission) {
            $problem = "None 'Read' permissions for Domain Computers or Authenticated users"
        }

        if ($unknownSID) {
            if ($problem) {
                $problem += "|Unknown SID object"
            }
            else {
                $problem = "Unknown SID object"
            }
        }
        if ($problem) {
            $Obj = New-Object -TypeName PSObject -Property ([ordered]@{
                    Problem          = $problem
                    UnknownRightsSID = $unknownSID
                    Path             = $GPO.Path
                    DisplayName      = $gpo.DisplayName
                    DomainName       = $gpo.DomainName
                    Owner            = $gpo.Owner
                    Id               = $gpo.Id
                    GpoStatus        = $gpo.GpoStatus
                    Description      = $gpo.Description
                    CreationTime     = $gpo.CreationTime
                    ModificationTime = $gpo.ModificationTime
                    WmiFilter        = $gpo.WmiFilter
                })
  
            $null = $MissingPermissionsGPOArray.Add($obj)
        }
    }
  
    # We also search in AD because if Authenticated Users are 'Deny' rights, the Get-GPO cmdlet does not return this GPO
    $GPOinAD = Get-ADObject -SearchBase "CN=Policies,CN=System,$((Get-ADRootDSE).defaultNamingContext)" -SearchScope OneLevel -Filter * 
    
    # If we cannot get the Name, it probalby means User Authenticated has Deny permission
    $GPOinAD | Where-Object { $_.Name -eq $null } | ForEach-Object {
  
        $Obj = New-Object -TypeName PSObject -Property ([ordered]@{
                Problem          = 'Policy object not readable in Active Directory'      
                UnknownRightsSID = '-'
                Path             = $_.DistinguishedName
                DisplayName      = '-'
                DomainName       = '-'
                Owner            = '-'
                Id               = '-'
                GpoStatus        = '-'
                Description      = '-'
                CreationTime     = '-'
                ModificationTime = '-'
                WmiFilter        = '-'
            })
  
        $null = $MissingPermissionsGPOArray.Add($obj)
    }
  
    if ($MissingPermissionsGPOArray.Count -ne 0) {
        Write-Warning  "$($MissingPermissionsGPOArray.Count) Group Policy Objects do not grant any read permissions to the 'Authenticated Users' or 'Domain Computers' groups."
        return $MissingPermissionsGPOArray
    }
    else {
        Write-Host "All Group Policy Objects grant required permissions. No issues were found." -ForegroundColor Green
    }
}