# Get the record A (host type) which are not domain controller on the root domain
function Get-DNSRootDomainRecords {
    Param(
        [Parameter(Mandatory)]
        [String]$DNSServer,
        [Parameter(Mandatory)]
        [String]$Domain
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

    # Resolve-DNS does not exist on older PowerShell version (2.0 and less)
    if ($dnsCmdLet) {
        $IPAddresses = (Resolve-DnsName $domain).IpAddress
    }
    else {
        $IPAddresses = ([Net.DNS]::GetHostEntry($domain)).AddressList
    }

    # Test DC not present in A records on the root domain (same as parent folder)
    $allDCIP | ForEach-Object {
        if (-not($IPAddresses -contains $_)) {
            $object = [ordered]@{
                IP          = $_
                ErrorType   = 'IP record Domain Controller Missing on root domain'
            }

            $recordsNotCompliant.Add($object)
            #Write-Warning "$_ is a domain controller but it is not on the root domain (same as parent folder)"
        }
    }

    # Test not DC address present in A records on the root domain (same as parent folder)
    $IPAddresses | ForEach-Object {
        if ($allDCIP -notcontains $_) {
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
            
            $object = [ordered]@{
                IP          = $return
                ErrorType   = 'Not an Domain controller IP'
            }

            $null = $recordsNotCompliant.Add($object)
            #Write-Warning "$return is on root domain $domain but it is not a domain controller"
        }
    }
	
    $allDCIP | ForEach-Object {
        if ($IPAddresses -notcontains $_) {
            Write-Warning "$_ domain controller missing on root domain $domain"

        }
    }
    <#
    if ($errors -eq 0) {
        Write-Host -ForegroundColor Green 'No issue found on the root domain records.'
    }
    #>

    return $recordsNotCompliant
}