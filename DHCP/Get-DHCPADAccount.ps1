#Requires -Version 5.0
#Requires -RunAsAdministrator 

function Get-DHCPADAccount {
	
	# check if DHCP RSAT tools are installed
	$dhcpInstalled = Get-WindowsFeature -Name 'RSAT-DHCP' | Where-Object { $_.Installed -eq $true }
	
	if (-not $dhcpInstalled) {
		Write-Warning 'DHCP RSAT tools are not installed'
		return
	}
	
	[System.Collections.Generic.List[PSObject]]$DHCPADAccountsArray = @()

	$dhcpsInAD = Get-DhcpServerInDC 

	foreach ($dhcp in $dhcpsInAD) {
		try {	
			
			$dhcpServerDnsCredential = Get-DhcpServerDnsCredential -ComputerName $dhcp.DnsName -ErrorAction Stop
			
			if ($dhcpServerDnsCredential.UserName) {
				$userName = $dhcpServerDnsCredential.UserName
			}
			else {
				$userName = '-'
			}
			if ($dhcpServerDnsCredential.DomainName) {
				$domainName = $dhcpServerDnsCredential.domainName
			}
			else {
				$domainName = '-'
			}
		}
		catch {
			Write-Warning "$($dhcp.DnsName) - $($_.Exception.Message)"
            
			$username = 'Error when get credentials'
			$domainName = 'Error when get credentials'
		}
    
		$object = [PSCustomObject][ordered]@{
			ComputerName = $dhcp.DnsName
			UserName     = $userName
			DomainName   = $domainName
		}

		$DHCPADAccountsArray.Add($object)
	}

	return $DHCPADAccountsArray
}