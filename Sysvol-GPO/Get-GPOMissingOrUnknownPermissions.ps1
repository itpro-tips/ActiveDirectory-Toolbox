Function Get-GPOMissingOrUnknownPermissions {
    
    [System.Collections.Generic.List[PSCustomObject]]$missingPermissionsGPOArray = @()

    $authenticatedUsersSID = 'S-1-5-11'
    $authenticatedUsersGroupName = New-Object System.Security.Principal.SecurityIdentifier ($authenticatedUsersSID)
    $authenticatedUsersGroupName = ($authenticatedUsersGroupName.Translate([System.Security.Principal.NTAccount])).Value
  
    $domainComputersSID = [string](Get-ADDomain).DomainSID + '-515'
    $domainComputersSID = New-Object System.Security.Principal.SecurityIdentifier ($domainComputersSID)
    $domainComputersGroupName = ($domainComputersSID.Translate([System.Security.Principal.NTAccount])).Value
    
    Write-Host 'Get all Group Policy Objects' -ForegroundColor Cyan

    $GPOs = Get-GPO -All
  
    Write-Host 'Get all Group Policy Objects permissions' -ForegroundColor Cyan
    
    $i = 0
    
    foreach ($GPO in $GPOs) {
        $i++

        Write-Host "$i/$($GPOS.count) Processing GPO '$($GPO.DisplayName)'" -ForegroundColor Cyan
        $GPOPermissions = Get-GPPermission -Guid $GPO.Id -All #| Select-Object -ExpandProperty Trustee | Where-Object { $_.SID -eq $AuthenticatedUsersSID }
        
        $readPermission = $false
        $unknownSID = $null
        foreach ($GPOPermission in $GPOPermissions) {
        
            $problem = $null
        
            if ($GPOPermission.Trustee.SidType -eq 'Unknown') {
                $unknownSID = $GPOPermission.Trustee.Sid
            }
            # Read in AD instead of Get-GPPermission because Permission returned does not present Read Permission if many permission exist
            $read = ((Get-Acl "AD:\$($GPO.Path)").Access | Where-Object { ($_.IdentityReference -eq "$domainComputersGroupName" -or -or $_.IdentityReference -eq "$authenticatedUsersGroupName") -and $_.ActiveDirectoryRights -match 'Read' }).AccessControlType
            
            if ($read -eq 'Allow') {
                $readPermission = $true
            }
        }
  
        if (-not $readPermission) {
            $problem = "None 'Read' permissions for Domain Users/Computers or Authenticated users (maybe you use a group instead?)"
        }

        if ($unknownSID) {
            if ($problem) {
                $problem += '|Unknown SID object'
            }
            else {
                $problem = 'Unknown SID object'
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
  
            $missingPermissionsGPOArray.Add($obj)
        }
    }
  
    # We also search in AD because if Authenticated Users are 'Deny' rights, the Get-GPO cmdlet does not return this GPO
    $GPOinAD = Get-ADObject -SearchBase "CN=Policies,CN=System,$((Get-ADRootDSE).defaultNamingContext)" -SearchScope OneLevel -Filter * 
    
    # If we cannot get the Name, it probably means User Authenticated has Deny permission
    $GPOinAD | Where-Object { $null -eq $_.Name } | ForEach-Object {
  
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
  
        $missingPermissionsGPOArray.Add($obj)
    }
  
    if ($missingPermissionsGPOArray.Count -ne 0) {
        Write-Warning  "$($missingPermissionsGPOArray.Count) Group Policy Objectswith some issues."
        return $missingPermissionsGPOArray
    }
    else {
        Write-Host 'All Group Policy Objects grant required permissions. No issues were found.' -ForegroundColor Green
    }
}