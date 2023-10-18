function Get-ADSchemaVersion {
    Param(
    )

    # https://learn.microsoft.com/en-us/troubleshoot/windows-server/identity/find-current-schema-version
    $adSchemaVersions = @{
        13 = 'Windows 2000 Server'
        30 = 'Windows Server 2003 RTM, Windows 2003 Service Pack 1, Windows 2003 Service Pack 2'
        31 = 'Windows Server 2003 R2'
        44 = 'Windows Server 2008 RTM'
        47 = 'Windows Server 2008 R2'
        56 = 'Windows Server 2012'
        69 = 'Windows Server 2012 R2'
        87 = 'Windows Server 2016'
        88 = 'Windows Server 2019/2022'
        90 = 'Windows Server 2025'
    }

    $adObjectVersion = (Get-ADObject (Get-ADRootDSE).schemaNamingContext -Property ObjectVersion).ObjectVersion

    if ($adSchemaVersions.ContainsKey($adObjectVersion)) {
        $adSchemaVersion = $adSchemaVersions[$adObjectVersion]
    }
    else {
        $adSchemaVersion = 'Unknown'
    }
        
    return $adSchemaVersion
}