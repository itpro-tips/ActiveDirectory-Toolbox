# https://docs.microsoft.com/en-us/troubleshoot/windows-server/identity/anonymous-ldap-operations-active-directory-disabled
function Get-AnonymousLDAPBindState {
    $enable = 'UNKNOWN'

    $directoryService = "CN=Directory Service,CN=Windows NT,CN=Services,CN=Configuration,$((Get-ADDomain).DistinguishedName)"

    $dsHeuristics = (Get-ADObject -Identity $directoryService -Properties dsHeuristics).dsHeuristics

    if (($dsHeuristics -eq '') -or ($dsHeuristics.Length -lt 7)) {  
        $enable = $false
    }
    elseif (($dsHeuristics.Length -ge 7) -and ($dsHeuristics[6] -eq "2")) {
        $enable = $true
    }

    return $enable
}