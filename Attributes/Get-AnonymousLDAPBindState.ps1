function Get-AnonymousLDAPBindState {
    $forestDN = $((Get-ADRootDSE).defaultNamingContext)

    $value = 'Unknown'

    $directoryService = "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$forestDN"

    $dsHeuristics = (Get-ADObject -Identity $directoryService -Properties dsHeuristics).dsHeuristics

    if (($dsHeuristics -eq '') -or ($dsHeuristics.Length -lt 7)) {  
        $value = 'Disabled'
    }
    elseif (($dsHeuristics.Length -ge 7) -and ($dsHeuristics[6] -eq "2")) {
        $value = 'Enabled'
    }

    return $value
}