$filesFound = New-Object System.Collections.ArrayList

$dnsDomain = $env:USERDNSDOMAIN
$netbiosDomain = $env:userdomain

$stringSearched = @(
    'password=',
    'password:',
    'passwd=',
    'passwd:',
    'pass=',
    'pass:',
    'pwd=',
    'pwd:',
    'password =',
    'password :',
    'passwd =',
    'passwd :',
    'pass =',
    'pass :',
    'pwd =',
    'pwd :',
    "$netbiosDomain\\",
    "$dnsDomain\\",
    "@$dnsDomain"
)

Write-Host -ForegroundColor Cyan "\\$dnsDomain\sysvol - Get all subfolders"

# Get all folders without catching error
# ignore ADM, ADMX or ADML files
$sysvolFolders = Get-ChildItem "\\$dnsDomain\sysvol" -Recurse -ErrorAction SilentlyContinue -ErrorVariable accessErrors | Where-Object { $_.FullName -notlike "\\$dnsDomain\sysvol\$dnsDomain\Policies\PolicyDefinitions\*.adm[xl]" -and $_.FullName -notlike "\\$dnsDomain\sysvol\*adm\*.adm"}

foreach ($accessError in $accessErrors) {
    Write-Warning "Unable to access $($accessError.CategoryInfo.TargetName). Reason:$($accessError.CategoryInfo.Reason)"
} 

Write-Host -ForegroundColor Cyan "\\$dnsDomain\sysvol - Found $($sysvolFolders.count) folders"

foreach ($string in $stringSearched) {
    Write-Host -ForegroundColor Cyan "\\$dnsDomain\sysvol - Search pattern '$string' in all sub files..."
    $found = $sysvolFolders | Select-String -Pattern $string
    
    $found | ForEach-Object {
        $object = New-Object -TypeName PSObject -Property ([ordered]@{
                Path       = $_.Path
                LineNumber = $_.LineNumber
                Line       = $_.Line
            })

        $null = $filesFound.add($object)
    }
}

return $filesFound