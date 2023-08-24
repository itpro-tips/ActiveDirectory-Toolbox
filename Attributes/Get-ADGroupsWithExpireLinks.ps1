# By default we don't see if a member of a group has a TTL set on it.
# We need to use specific LDAP Control LDAP_SERVER_LINK_TTL_OID to get this information.
[string]$LDAP_SERVER_LINK_TTL_OID = '1.2.840.113556.1.4.2309'

[System.Collections.Generic.List[PSObject]]$groupsWithTTL = @()

# Load required .NET assemblies
Add-Type -AssemblyName "System.DirectoryServices.Protocols"

# Get domain details
$rootDSE = Get-ADRootDSE
$domainDN = $rootDSE.defaultNamingContext
$domainServer = ($rootDSE.dnsHostName)

# Connect to LDAP
$ldapConnection = New-Object System.DirectoryServices.Protocols.LdapConnection $domainServer

# Define the search scope
$searchScope = [System.DirectoryServices.Protocols.SearchScope]::Subtree

# Create search request with desired base DN, filter, and search scope
$searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $domainDN, "(&(objectClass=group)(member=*))", $searchScope

# Add the LDAP control to the search request
# By default we don't see if a member of a group has a TTL set on it.
[void]$searchRequest.Controls.Add((New-Object "System.DirectoryServices.Protocols.DirectoryControl" -ArgumentList "$LDAP_SERVER_LINK_TTL_OID", $null, $false, $true ))

# Perform the search
$searchResponse = $ldapConnection.SendRequest($searchRequest)

# Display the results
$searchResponse.Entries | ForEach-Object {
    # $_.Attributes['member'] can have multiple values so we need to loop through them but we need to do with for i++ instead of foreach because it's a way to get a string instead of byte array (byte[])
    for ($i = 0; $i -lt $_.Attributes['member'].Count; $i++) {
        
        if ($_.Attributes['member'][$i] -like '<TTL=*>,*') {
            $memberString = $_.Attributes['member'][$i]
            $object = [PSCustomObject][ordered]@{
                Group  = $_.DistinguishedName
                Member = [regex]::Match($memberString, ',(.+)').Groups[1].Value # supress TTL
                # Get the TTL value from the member attribute
                # we need to use match to get the value between the '=' and '>' characters
                TTL    = [regex]::Match($memberString, '<TTL=(\d+)>').Groups[1].Value
            }

            $groupsWithTTL.Add($object)
        }
    }
}

return $groupsWithTTL