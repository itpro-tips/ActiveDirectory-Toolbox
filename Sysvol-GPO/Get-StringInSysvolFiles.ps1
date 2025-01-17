﻿function Get-StringInSysvolFiles {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [String]$dnsDomain = $env:USERDNSDOMAIN,
        [Parameter(Mandatory = $false)]
        [String]   $netbiosDomain = $env:userdomain
    )    

    [System.Collections.Generic.List[PSCustomObject]]$filesFound = @()
        
    #space or no space \s*
    $stringSearched = @(
        'password\s?=',
        'password\s?:',
        'passwd\s?=',
        'passwd\s?:',
        'pass\s?=',
        'pass\s?:',
        'pwd\s?=',
        'pwd\s?:'
    )
    
    Write-Host -ForegroundColor Cyan "\\$dnsDomain\sysvol - Get all subfolders (.adm, .admx and .adml files are excluded)"
    
    # Get all folders without catching error
    # ignore ADM, ADMX or ADML files
    $sysvolFolders = Get-ChildItem "\\$dnsDomain\sysvol" -Recurse -ErrorAction SilentlyContinue -ErrorVariable accessErrors | Where-Object { $_.FullName -notlike "\\$dnsDomain\sysvol\$dnsDomain\Policies\PolicyDefinitions\*.adm[xl]" -and $_.FullName -notlike "\\$dnsDomain\sysvol\*adm\*.adm" }
    
    foreach ($accessError in $accessErrors) {
        Write-Warning "Unable to access $($accessError.CategoryInfo.TargetName). Reason:$($accessError.CategoryInfo.Reason)"
    } 
    
    Write-Host -ForegroundColor Cyan "\\$dnsDomain\sysvol - Found $($sysvolFolders.count) folders"
    
    foreach ($string in $stringSearched) {
        Write-Host -ForegroundColor Cyan "\\$dnsDomain\sysvol - Search pattern '$string' in all sub files..."
        $found = $sysvolFolders | Select-String -Pattern $string -AllMatches
        
        $found | ForEach-Object {
            $object = [PSCustomObject][ordered]@{
                Path       = $_.Path
                LineNumber = $_.LineNumber
                Line       = $_.Line
            }
    
            $filesFound.add($object)
        }
    }
    
    return $filesFound
}