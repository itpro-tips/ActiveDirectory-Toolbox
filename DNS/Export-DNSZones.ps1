$DNSServer = Get-Content env:computername

$BackupFolder = "c:\Windows\System32\DNS\backup"
$zonesFile = Join-Path $BackupFolder "zonesFile.csv"

# Si le dossier n'existe pas, il est créé
if (-not(Test-Path $BackupFolder)) {
    New-Item $BackupFolder -Type Directory | Out-Null
} 
# Si le dossier existe, on supprimer le contenu
else {
    Remove-Item $BackupFolder"\*" -recurse
}

# Paramètres DNS
$List = Get-WmiObject -ComputerName $DNSServer -Namespace root\MicrosoftDNS -Class MicrosoftDNS_Zone

# Export des informations DNS vers le fichier $zonesFile
$list | Select-Object Name, ZoneType, AllowUpdate, @{Name = "MasterServers"; Expression = { $_.MasterServers } }, DsIntegrated | Export-csv $zonesFile -NoTypeInformation

# Export des zones DNS
$list | ForEach-Object {
    $path = "backup\" + $_.name
    $cmd = "dnscmd {0} /ZoneExport {1} {2}" -f $DNSServer, $_.Name, $path
    Invoke-Expression $cmd
}