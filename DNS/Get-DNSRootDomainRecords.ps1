# Get the record A (host type) which are not domain controller on the root domain
function Get-DNSRootDomainRecords
{
    $dnsCmdLet = $true
    $allDCIP = New-Object System.Collections.ArrayList
    $domain = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name
    $errors = 0
	$recordsNotCompliant = New-Object System.Collections.ArrayList

    # Works with all Windows version (2012+ can use Resolve-DNSName)
    Get-ADDomainController -Filter * | ForEach-Object{
        $null = $allDCIP.Add($_.Ipv4Address)
    }

    try{
        Get-Command Resolve-DnsName | Out-Null
    }
    catch
    {
        $dnsCmdLet = $false
    }
    # Resolve-DNS does not exist on older PowerShell version (2.0 and less)
    if($dnsCmdLet){
        $IPAddresses = (Resolve-DnsName $domain).IpAddress
    }
    else
    {
        $IPAddresses = ([Net.DNS]::GetHostEntry($domain)).AddressList
    }

    # Test DC not present in A records on the root domain (same as parent folder)
    $allDCIP | ForEach-Object {
        if(-not($IPAddresses -contains $_)){
            Write-Warning "$_ is a domain controller but it is not on the root domain (same as pparent folder)"
            $errors++
        }
    }

    # Test not DC address present in A records on the root domain (same as parent folder)
    $IPAddresses | ForEach-Object{
        if($allDCIP -notcontains $_){
            $errors++
            if($dnsCmdLet){
                try{
                    $return = Resolve-DnsName $_ -QuickTimeout -ErrorAction SilentlyContinue
                }
                catch
                {
                    
                }
            }
            else{
                $return = [Net.DNS]::GetHostEntry($_) # take time when not exist (5secs timeout)
            }

            if($null -eq $return){
                $return = $_
            }
            else{
				if($dnsCmdLet){
					$return = "$($return.NameHost) - $_"
				}
                else{
					$return = "$($return.Hostname) - $_"
				}
            }
			
			$null = $recordsNotCompliant.Add($return)
            Write-Warning "$return is on root domain $domain but it is not a domain controller"
        }
    }
	
	$allDCIP | ForEach-Object{
		if($IPAddresses -notcontains $_)
		{
			Write-Warning "$_ domain controller missing on root domain $domain"
		}
	}
    if($errors -eq 0){
        Write-Host -ForegroundColor Green 'No issue found on the root domain records.'
    }
}