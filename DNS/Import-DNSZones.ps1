$DNSServer = Get-Content env:computername

$BackupFolder = "C:\Windows\System32\dns\backup"

$zonesFile = Join-Path $BackupFolder "zonesFile.csv"

$zones = Import-Csv $zonesFile
$zones | ForEach-Object {

    $path = "backup\" + $_.name
    $Zone = $_.name
    $IP = $_.MasterServers
    $Update = $_.AllowUpdate

    if ($_.DsIntegrated -eq $True) {
        Switch ($_.ZoneType) {
            1 {
                # Création de la zone en tant que zone primaire
                $cmd0 = "dnscmd {0} /ZoneAdd {1} /primary /file {2} /load" -f $DNSServer, $Zone, $path
                Invoke-Expression $cmd0
                $cmd1 = "dnscmd {0} /ZoneResetType {1} /dsprimary" -f $DNSServer, $Zone
            }

            3 {
                $cmd1 = "dnscmd {0} /ZoneAdd {1} /dsstub {2} /load" -f $DNSServer, $Zone, $IP
            }

            4 {
                $cmd1 = "dnscmd {0} /ZoneAdd {1} /dsforwarder {2} /load" -f $DNSServer, $Zone, $IP
            }
        }
    }
    else {

        Switch ($_.ZoneType) {
            1 {
                $cmd1 = "dnscmd {0} /ZoneAdd {1} /primary /file {2} /load" -f $DNSServer, $Zone, $path
            }

            2 {
                $cmd1 = "dnscmd {0} /ZoneAdd {1} /secondary {2}" -f $DNSServer, $Zone, $IP
            }

            3 {
                $cmd1 = "dnscmd {0} /ZoneAdd {1} /stub {2}" -f $DNSServer, $Zone, $IP
            }

            4 {
                $cmd1 = "dnscmd {0} /ZoneAdd {1} /forwarder {2}" -f $DNSServer, $Zone, $IP
            }
        }
    }

    # Restauration des zones DNS
    Invoke-Expression $cmd1

    # Configuration du type de mise à jour 
    Switch ($_.AllowUpdate) {
        # Aucune mise à jour
        0
        { $cmd2 = "dnscmd /Config {0} /allowupdate {1}" -f $Zone, $Update }
        
        # Mises à jour sécurisées et non sécurisées
        1 {
            $cmd2 = "dnscmd /Config {0} /allowupdate {1}" -f $Zone, $Update
        }

        # Mises à jour sécurisées uniquement
        2 {
            $cmd2 = "dnscmd /Config {0} /allowupdate {1}" -f $Zone, $Update
        }
    }

    # Réinitialiser les paramètres DNS
    Invoke-Expression $cmd2
}