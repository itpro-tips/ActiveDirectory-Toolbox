# inspired from https://gallery.technet.microsoft.com/scriptcenter/Find-missing-Reverse-DNS-80e681d8
# Modified by Bastien Perez (15 january 2021)

function Get-DNSMissingReverseZones {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[String]$DNSServer
	)

	[System.Collections.Generic.List[PSCustomObject]]$dnsEntries = @()
	[System.Collections.Generic.List[PSCustomObject]]$dnsResult = @()
	[System.Collections.Generic.List[PSCustomObject]]$missingZones = @()
	[System.Collections.Generic.List[PSCustomObject]]$reverseResult = @()
	[System.Collections.Generic.List[PSCustomObject]]$dnsResult = @()

	if ($DNSServer) {
		$dnsDirectZones = @(Get-DnsServerZone -ComputerName $DNSServer | Where-Object { $_.ISReverseLookupZone -eq $false })
		$dnsReverseZones = @(Get-DnsServerZone -ComputerName $DNSServer | Where-Object { $_.IsReverseLookupZone })
	}
	else {
		$dnsDirectZones = @(Get-DnsServerZone | Where-Object { $_.ISReverseLookupZone -eq $false })
		$dnsReverseZones = @(Get-DnsServerZone  | Where-Object { $_.IsReverseLookupZone })
	}

	foreach ($dnsDirectZone in $dnsDirectZones) {
		if ($DNSServer) {
			$ips = Get-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $dnsDirectZone.ZoneName | Select-Object HostName, @{n = 'RecordData'; e = { if ($_.RecordData.IPv4Address.IPAddressToString) { $_.RecordData.IPv4Address.IPAddressToString } else { "" } } }
		}
		else {
			$ips = Get-DnsServerResourceRecord -ZoneName $dnsDirectZone.ZoneName | Select-Object HostName, @{n = 'RecordData'; e = { if ($_.RecordData.IPv4Address.IPAddressToString) { $_.RecordData.IPv4Address.IPAddressToString } else { "" } } }
		}
		
		#Where-Object {($_.RecordData -ne '') -and ($_.RecordType -eq 'A' -or $_.RecordType -eq 'AAAA')}).RecordData.IPV4Address.IPAddressToString
		
		$ips | ForEach-Object {
			$dnsEntries.Add($_)
		}
	}

	foreach ($dnsReverseZone in $dnsReverseZones) {
		$ipAddressParts = $dnsReverseZone.ZoneName.Split('.')
		$reverseResult.Add($ipAddressParts[2] + "." + $ipAddressParts[1] + "." + $ipAddressParts[0])
	}

	foreach ($dnsEntry in $dnsEntries) {
		$ipAddressParts = $dnsEntry.RecordData.Split('.')
		$tmpResult = $ipAddressParts[0] + "." + $ipAddressParts[1] + "." + $ipAddressParts[2]
		if ($tmpResult -notcontains "..") {
			$dnsResult.Add($tmpResult)
		}
	}

	$missingZones = $dnsResult | Where-Object { $reverseResult -notcontains $_ } | Sort-Object | Get-Unique -AsString | Select-Object @{Name = 'Missing DNS Reverse Zone'; Expression = { "$_" } }

	if (-not $missingZones) {
		Write-Host -ForegroundColor Green 'No DNS Reverse zones missing'
	}

	return $missingZones | Sort-Object
}