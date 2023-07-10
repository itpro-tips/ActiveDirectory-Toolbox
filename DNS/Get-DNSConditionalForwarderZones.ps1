function Get-DNSConditionalForwarderZones {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $false)]
		[String]$DNSServer
	)

    $object = @(Get-DnsServerZone -ComputerName $DNSServer | Where-Object {$_.ZoneType -eq 'Forwarder'})

    return $object
}