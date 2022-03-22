# inspired from https://gallery.technet.microsoft.com/scriptcenter/Find-missing-Reverse-DNS-80e681d8
# Modified by Bastien Perez (15 january 2021)

function Get-DNSMissingReverseZones {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory)]
		[String]$DNSServer
	)

	$dnsEntries = New-Object System.Collections.ArrayList
	$dnsResult = New-Object System.Collections.ArrayList
	$missingZones = New-Object System.Collections.ArrayList
	$reverseResult = New-Object System.Collections.ArrayList
	$dnsResult = New-Object System.Collections.ArrayList

	$dnsDirectZones = @(Get-DnsServerZone -ComputerName $DNSServer | Where-Object { $_.ISReverseLookupZone -eq $false })
	$dnsReverseZones = @(Get-DnsServerZone -ComputerName $DNSServer | Where-Object { $_.IsReverseLookupZone -eq $true })

	foreach ($dnsDirectZone in $dnsDirectZones) {
		$ips = Get-DnsServerResourceRecord -ComputerName $DNSServer -ZoneName $dnsDirectZone.ZoneName | Select-Object HostName, @{n = 'RecordData'; e = { if ($_.RecordData.IPv4Address.IPAddressToString) { $_.RecordData.IPv4Address.IPAddressToString } else { "" } } }
		#Where-Object {($_.RecordData -ne '') -and ($_.RecordType -eq 'A' -or $_.RecordType -eq 'AAAA')}).RecordData.IPV4Address.IPAddressToString
		
		$ips | ForEach-Object {
			$null = $dnsEntries.Add($_)
		}
	}

	foreach ($dnsReverseZone in $dnsReverseZones) {
		$ipAddressParts = $dnsReverseZone.ZoneName.Split('.')
		#$result+= $ipAddressParts[2] + "." + $ipAddressParts[1] + "." + $ipAddressParts[0]
		$null = $reverseResult.Add($ipAddressParts[2] + "." + $ipAddressParts[1] + "." + $ipAddressParts[0])
	}

	foreach ($dnsEntry in $dnsEntries) {
		$ipAddressParts = $dnsEntry.RecordData.Split('.')
		$tmpResult = $ipAddressParts[0] + "." + $ipAddressParts[1] + "." + $ipAddressParts[2]
		if ($tmpResult -notcontains "..") {
			#$dnsResult += $tmpResult
			$null = $dnsResult.Add($tmpResult)
		}
	}

	$missingZones = $dnsResult | Where-Object { $reverseResult -notcontains $_ } | Sort-Object | Get-Unique -AsString

	return $missingZones
}