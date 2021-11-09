# Get the record A (host type) which are not domain controller on the root domain
function Get-DNSDCRecords {
    Param(
        [Parameter(Mandatory)]
        [String]$DNSServer,
        [Parameter(Mandatory)]
        [String]$Domain,
        [string[]]$Zones = $domain
    )
	
    $dnsCmdLet = $true

    [System.Collections.Generic.List[PSObject]]$allDCIP = @()
    [System.Collections.Generic.List[PSObject]]$records = @()

    # Works with all Windows version (2012+ can use Resolve-DNSName)
    Get-ADDomainController -Filter { Domain -eq $Domain }  | ForEach-Object {
        $allDCIP.Add($_.Ipv4Address)
    }

    try {
        $null = Get-Command Resolve-DnsName
    }
    catch {
        $dnsCmdLet = $false
    }

    foreach ($zone in $zones) {
        # Resolve-DNS does not exist on older PowerShell version (2.0 and less)
        if ($dnsCmdLet) {
            $IPAddresses = (Resolve-DnsName $zone).IpAddress
        }
        else {
            $IPAddresses = ([Net.DNS]::GetHostEntry($zone)).AddressList
        }

        # Test DC not present in A records on the root domain (same as parent folder)
        $allDCIP | ForEach-Object {
            if (-not($IPAddresses -contains $_)) {
                $object = [PSCustomObject][ordered]@{
                    IP      = $_
                    Type    = "IP record Domain Controller Missing on $zone"
                }
            }
            else {
                $object = [PSCustomObject][ordered]@{
                    IP      = $_
                    Type    = "A record"
                }
            }
            
            $records.Add($object)
        }

        # Test not DC address present in A records on the root domain (same as parent folder)
        $IPAddresses | ForEach-Object {
            if ($allDCIP -notcontains $_ -and $null -ne $_) {
                if ($dnsCmdLet) {
                    try {
                        $return = Resolve-DnsName $_ -QuickTimeout -ErrorAction SilentlyContinue
                    }
                    catch {
                        
                    }
                }
                else {
                    $return = [Net.DNS]::GetHostEntry($_) # take time when not exist (5secs timeout)
                }

                if ($null -eq $return) {
                    $return = $_
                }
                else {
                    if ($dnsCmdLet) {
                        $return = "$($return.NameHost) - $_"
                    }
                    else {
                        $return = "$($return.Hostname) - $_"
                    }
                }
                
                $object = [PSCustomObject][ordered]@{
                    IP        = $return
                    Type = "Not an Domain controller IP on $zone"
                }

                $records.Add($object)
            }
        }
    }

    return $records
}