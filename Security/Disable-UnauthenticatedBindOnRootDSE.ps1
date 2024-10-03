function Disable-UnauthenticatedBindOnRootDSE {
    Write-Host 'Disabling anonymous LDAP...' -ForegroundColor Cyan
    Write-Host 'The Windows Server running domain controller must be Windows Server 2019 or later' -ForegroundColor Cyan
    
    $rootDSE = Get-ADRootDSE
    $directoryServiceObject = "CN=Directory Service,CN=Windows NT,CN=Services,$($rootDSE.ConfigurationNamingContext)"
    
    try {
        Set-ADObject -Identity $directoryServiceObject -Add @{ 'msDS-Other-Settings' = 'DenyUnauthenticatedBind=1' }
        Write-Host 'Anonymous LDAP bind has been disabled' -ForegroundColor Green
    }
    catch {
        Write-Warning "$($_.Exception.Message)"
    }
}