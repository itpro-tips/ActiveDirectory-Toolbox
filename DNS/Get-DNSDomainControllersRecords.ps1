# Get the record A (host type) which are not domain controller on the root domain
function Get-DNSDomainControllersRecords {
    Param(
        [Parameter(Mandatory)]
        [String]$DNSServer,
        [Parameter(Mandatory)]
        [String]$Domain,
        [string[]]$Zones = $domain
    )
	
    $dnsCmdLet = $true
    $allDCIP = New-Object System.Collections.ArrayList
    $recordsNotCompliant = New-Object System.Collections.ArrayList

    # Works with all Windows version (2012+ can use Resolve-DNSName)
    Get-ADDomainController -Filter {Domain -eq $Domain}  | ForEach-Object {
        $null = $allDCIP.Add($_.Ipv4Address)
    }

    try {
        $null = Get-Command Resolve-DnsName
    }
    catch {
        $dnsCmdLet = $false
    }

    foreach($zone in $zones){
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
                $object = New-Object -TypeName PSObject -Property ([ordered]@{
                    IP          = $_
                    ErrorType   = "IP record Domain Controller Missing on $zone"
                })

                $null = $recordsNotCompliant.Add($object)
            }
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
                
                $object = New-Object -TypeName PSObject -Property ([ordered]@{
                    IP          = $return
                    ErrorType   = "Not an Domain controller IP on $zone"
                })

                $null = $recordsNotCompliant.Add($object)
            }
        }
    }

    return $recordsNotCompliant
}