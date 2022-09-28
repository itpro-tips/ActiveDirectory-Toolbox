# Get GPO in Active Directory and Sysvol and compare if present
function Get-GPOConsistencyBetweenDirectoryAndSysvol {
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

    [System.Collections.Generic.List[PSCustomObject]]$gpoResults = @()

    foreach ($DC in $DomainController) {
        [array]$GPOs = @(Get-GPO -All -Server $DC)

        try {
            $SYSVOL = Get-ChildItem -Path "\\$DC\SYSVOL\$Domain\Policies" -ErrorAction Stop | Where-Object { $_.PsIsContainer -and $_.FullName -notmatch 'PolicyDefinitions' }
        }
        catch {
            Write-Warning "Error connecting to 'SYSVOL' folder on ($DC). Fix this problem and retry"
            break
        }

        if (Test-Path -Path "\\$DC\SYSVOL\$Domain\Policies\PolicyDefinitions" -ErrorAction SilentlyContinue) {
            Write-Host -ForegroundColor green 'PolicyDefinitions is present!'
        }
        else {
            Write-Warning 'PolicyDefinitions folder is not present, considere to create one to keep consistency in ADM/ADMX.'
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

                $object = New-Object -TypeName PSObject -Property @{
                    FromDC = $DC
                    Name   = $Name
                    Status = $Status
                    GUID   = $ID
                }

                $gpoResults.Add($object)
            }

            Write-Host -ForegroundColor green "Below information taken from ($DC) :
    SysVol: $CountSysvol
    GPO   : $CountGPOs

It seems you have no inconsistency issues between SYSVOL and GPOs on your DC $DC." 

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
    
                $object = New-Object -TypeName PSObject -Property @{
                    FromDC = $DC
                    Name   = $Name
                    Status = $Status
                    GUID   = $ID
                }
            
                $gpoResults.Add($object)
            }

            $countPhantoms = ($gpoResults | Where-Object { $_.Status -eq 'Phantom' -or $_.Status -eq 'Missing' }).count
            Write-Warning "Below information taken from $DC :

    SysVol: $CountSysvol
    GPO   : $CountGPOs

You probably need to carefuly remove items marked with 'Phantom' from you SYSVOL. There are about $CountPhantoms phantom folders in SYSVOL directory of $DC"

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

                $object = New-Object -TypeName PSObject -Property @{
                    FromDC = $DC
                    Name   = $Name
                    Status = $Status
                    GUID   = $ID
                }

                $gpoResults.Add($object)
            }
        }

        Write-Warning  "Below information taken from $DC :

    SysVol: $CountSysvol
    GPO   : $CountGPOs

It seems there are problems with some GPOs. There is a high chance that you have GPOs where there is no associated folder for them in SYSVOL directory of $DC.

Below policies are missing from SYSVOL of PDC Emulator. Possible solutions are restoring this GPOS from backup and import it on PDC or, change the PDC to the DC who has these missing GPOs in their SYSVOL:
    "
    }

    $gpoResults
}