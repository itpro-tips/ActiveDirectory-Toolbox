# Get GPO in Active Directory and Sysvol and compare if present
function Get-GPOConsistencyArrayBetweenDirectoryAndSysvol {
    Param(
        [Parameter(Mandatory = $false)]
        [string[]]$DomainController,
        [Parameter(Mandatory = $false)]
        [string]$Domain
    )

    #$pdcEmulator = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner

    if (-not $DomainController) {
        $DomainController = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers
    }

    if (-not $Domain) {
        $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
    }

    [System.Collections.Generic.List[PSCustomObject]]$gpoConsistencyArray = @()

    foreach ($DC in $DomainController) {
        try {   
            [array]$GPOs = @(Get-GPO -All -Server $DC -ErrorAction Stop)
        }
        catch {
            $object = [PSCustomObject][ordered]@{
                FromDC = $DC
                Name   = $_.Exception.Message
                Status = '-'
                GUID   = '-'
            }
    
            $gpoConsistencyArray.Add($object)
            continue
        }
        try {
            $SYSVOL = Get-ChildItem -Path "\\$DC\SYSVOL\$Domain\Policies" -ErrorAction Stop | Where-Object { $_.PsIsContainer -and $_.FullName -notmatch 'PolicyDefinitions' }
        }
        catch {
            $object = [PSCustomObject][ordered]@{
                FromDC = $DC
                Name   = $_.Exception.Message
                Status = '-'
                GUID   = '-'
            }
        
            $gpoConsistencyArray.Add($object)
            continue
        }

        if (Test-Path -Path "\\$DC\SYSVOL\$Domain\Policies\PolicyDefinitions" -ErrorAction SilentlyContinue) {
            Write-Host -ForegroundColor green "$DC - PolicyDefinitions is present!"
        }
        else {
            Write-Warning "$DC - PolicyDefinitions folder is not present, considere to create one to keep consistency in ADM/ADMX."
        }    
 
        [array]$SYSVOLIds = ((($SYSVOL).Name) -replace '{', '') -replace '}', ''

        $CountSysvol = $SYSVOL.Count
        $CountGPOs = $GPOs.Count

        if ($CountSysvol -eq $CountGPOs) {
            foreach ($Item in $SYSVOL) {
                $ID = (($Item.Name) -replace '{', '') -replace '}', ''

                try {
                    if (Get-GPO -Guid $ID -Domain $Domain -ErrorAction Stop) {
                        $GPO = Get-GPO -Guid $ID -Domain $Domain
                        $Name = $GPO.DisplayName
                        $Status = 'OK'
                    }
                }
                catch {
                    $Status = 'GPO Missing'
                    $Name = 'N/A'
                }

                $object = [PSCustomObject][ordered]@{
                    FromDC = $DC
                    Name   = $Name
                    Status = $Status
                    GUID   = $ID
                }

                $gpoConsistencyArray.Add($object)
            }
        }

        elseif ($CountSysvol -gt $CountGPOs) {
            foreach ($Item in $SYSVOL) {
                $ID = (($Item.Name) -replace '{', '') -replace '}', ''

                try {
                    $GPO = Get-GPO -Guid $ID -Domain $Domain -ErrorAction Stop

                    $Name = $GPO.DisplayName
                    $Status = 'OK'
                }

                catch {
                    $Status = 'Phantom (Folder exist in GPO but not in AD)'
                    $Name = 'N/A'
                }
    
                $object = [PSCustomObject][ordered]@{
                    FromDC = $DC
                    Name   = $Name
                    Status = $Status
                    GUID   = $ID
                }
            
                $gpoConsistencyArray.Add($object)
            }
        }

        elseif ($CountSysvol -lt $CountGPOs) {
            foreach ($GPO in $GPOs) {
                $Name = $GPO.DisplayName
                $ID = $GPO.Id
        
                if ($ID -in $SYSVOLIds) {
                    $Status = 'OK'
                }

                else {
                    $Status = 'Folder Missing'
                }

                $object = [PSCustomObject][ordered]@{
                    FromDC = $DC
                    Name   = $Name
                    Status = $Status
                    GUID   = $ID
                }

                $gpoConsistencyArray.Add($object)
            }
        }
    }

    $gpoConsistencyArray
}