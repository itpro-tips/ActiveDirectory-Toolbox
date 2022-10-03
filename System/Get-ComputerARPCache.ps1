# Inspired by https://github.com/BornToBeRoot/PowerShell/blob/master/Module/LazyAdmin/Functions/Network/Get-ARPCache.ps1
function Get-ComputerARPCache {
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    
    [System.Collections.Generic.List[PSObject]]$arpCacheArray = @()

    # Regex for IPv4-Address
    $regexIPv4Address = "(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)"
    $regexMACAddress = "([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})|([0-9A-Fa-f]{2}){6}"

    # Get the arp cache.
    if ($ComputerName) {
        $arpCacheRaw = Invoke-Command -ComputerName $ComputerName { arp -a }
    }
    else {
        $computerName = $env:COMPUTERNAME
        $arpCacheRaw = arp -a
    }

    foreach ($line in $arpCacheRaw) {
        # Detect line where interface starts
        if ($line -like "*---*") {
            $interfaceIPv4 = [regex]::Matches($line, $regexIPv4Address).Value
        }
        elseif ($line -match $regexMACAddress) {            
            foreach ($split in $line.Split(" ")) {
                if ($split -match $regexIPv4Address) {
                    $IPv4Address = $split
                }
                elseif ($split -match $regexMACAddress) {
                    $MACAddress = $split.ToUpper()    
                }
                elseif (-not([String]::IsNullOrEmpty($split))) {
                    $Type = $split
                }
            }

            $object = [PSCustomObject][ordered]@{
                ComputerName = $ComputerName
                Interface    = $interfaceIPv4
                IPv4Address  = $IPv4Address
                MACAddress   = $MACAddress
                Type         = $Type
            }

            $arpCacheArray.Add($object)
        }
    }

    return $arpCacheArray
}