function Get-DNSOrphanedZones {
    [CmdletBinding()]
    param(
        # Parameter help description
        [Parameter(Mandatory)]
        [String]$DomainNamingContext
    )
    $DNSOrphanedZones = New-Object System.Collections.ArrayList

    Get-ADObject -SearchBase "CN=MicrosoftDNS,DC=DomainDnsZones,$DomainNamingContext" -SearchScope OneLevel -Filter { Name -like '*CNF:*' } | ForEach-Object {
        $null = $DNSOrphanedZones.Add($_.DistinguishedName)
    }
    
    Get-ADObject -SearchBase "CN=MicrosoftDNS,DC=ForestDnsZones,$DomainNamingContext" -SearchScope OneLevel -Filter { Name -like '*CNF:*' } | ForEach-Object {
        $null = $DNSOrphanedZones.Add($_.DistinguishedName)
    }
    
    return $DNSOrphanedZones
}