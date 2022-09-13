function Get-DNSOrphanedZones {
    [CmdletBinding()]
    param(
    )
    
    [System.Collections.Generic.List[PSObject]]$DNSOrphanedZones = @()
    
    $domainNamingContext = (Get-ADRootDSE).defaultnamingcontext

    Get-ADObject -SearchBase "CN=MicrosoftDNS,DC=DomainDnsZones,$domainNamingContext" -SearchScope OneLevel -Filter { Name -like '*CNF:*' } | ForEach-Object {
        $DNSOrphanedZones.Add($_.DistinguishedName)
    }
    
    Get-ADObject -SearchBase "CN=MicrosoftDNS,DC=ForestDnsZones,$domainNamingContext" -SearchScope OneLevel -Filter { Name -like '*CNF:*' } | ForEach-Object {
        $DNSOrphanedZones.Add($_.DistinguishedName)
    }
    
    if (-not $DNSOrphanedZones) {
        Write-Host -ForegroundColor Green 'No DNS Orphaned Zones'
    }

    return $DNSOrphanedZones
}