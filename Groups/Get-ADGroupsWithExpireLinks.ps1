# By default we don't see if a member of a group has a TTL set on it.
# We need to use specific LDAP Control LDAP_SERVER_LINK_TTL_OID to get this information.
[string]$LDAP_SERVER_LINK_TTL_OID = '1.2.840.113556.1.4.2309'

# Uncomment the following line if you want to retrieve additional attributes for each member
# $membersAttributes = @('DisplayName', 'Description', 'mail', 'telephoneNumber', 'mobile', 'title', 'department', 'company', 'physicalDeliveryOfficeName', 'streetAddress', 'l', 'st', 'postalCode', 'c', 'co', 'manager')

# Uncomment the following line if you want to retrieve additional attributes for each group
#$groupsAttributes = @('cn', 'samaccountname', 'Description')

[System.Collections.Generic.List[PSObject]]$groupsWithExpireLinks = @()

# Load required .NET assemblies
Add-Type -AssemblyName "System.DirectoryServices.Protocols"

# Get domain details
$rootDSE = [ADSI]'LDAP://RootDSE'
$domainDN = $rootDSE.defaultNamingContext
$domainServer = ($rootDSE.dnsHostName)

function Search-LDAPWitLDAPControl {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$DomainServer,
        [Parameter(Mandatory = $true)]
        [string]$DomainDN,
        [Parameter(Mandatory = $true)]
        [string]$LdapFilter,
        [Parameter(Mandatory = $true)]
        $SearchScope,
        [Parameter(Mandatory = $false)]
        $Attributes,
        [Parameter(Mandatory = $true)]
        $LdapConnection,
        [Parameter(Mandatory = $false)]
        $LdapControlOID
    )

    $searchRequest = New-Object System.DirectoryServices.Protocols.SearchRequest -ArgumentList $domainDN, $ldapFilter, $searchScope, $attributes
    
    # Add the LDAP control to the search request
    # By default we don't see if a member of a group has a TTL set on it.
    # https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.directorycontrol.-ctor?view=dotnet-plat-ext-7.0
    # public DirectoryControl (string type, byte[] value, bool isCritical, bool serverSide);
    if ($ldapControlOID) {
        $ldapControl = New-Object System.DirectoryServices.Protocols.DirectoryControl -ArgumentList $LdapControlOID, $null, $false, $true
        [void]$searchRequest.Controls.Add($ldapControl)
    }

    # Perform the search
    $searchResponse = $ldapConnection.SendRequest($searchRequest)

    return $searchResponse

}

# Connect to LDAP
$ldapConnection = New-Object System.DirectoryServices.Protocols.LdapConnection $domainServer

# Define the search scope
$searchScope = [System.DirectoryServices.Protocols.SearchScope]::Subtree

# Create search request with desired base DN, filter, and search scope
# public SearchRequest (string distinguishedName, string ldapFilter, System.DirectoryServices.Protocols.SearchScope searchScope, params string[] attributeList);

# https://learn.microsoft.com/en-us/dotnet/api/system.directoryservices.protocols.searchrequest.-ctor?view=dotnet-plat-ext-7.0#system-directoryservices-protocols-searchrequest-ctor(system-string-system-string-system-directoryservices-protocols-searchscope-system-string())
$ldapFilter = '(objectClass=group)'
# we don't specify attributeList because we want all attributes
$attributes = $null

$entries = Search-LDAPWitLDAPControl -DomainServer $domainServer -DomainDN $domainDN -LdapFilter $ldapFilter -SearchScope $searchScope -LdapControlOID $LDAP_SERVER_LINK_TTL_OID -LdapConnection $ldapConnection

# Get the current time
$searchTime = [System.DateTime]::Now

# Display the results
foreach ($entry in $entries.Entries) {
    [System.Collections.Generic.List[PSObject]]$allMembers = @()

    $isBigGroup = $false
    # If the group is too large (i.e. more than 1500 members by default in AD), the member attribute will only contain a range of members.
    # As long as there are less than 1500 members in the group, they can be viewed in the members field in AD.
    #Above 1500 members, the "members" field is empty and members can be viewed in the "member;range=0-1499" field.
    $isBigGroup = [bool]($entry.Attributes.AttributeNames -like "member;range=*")
    
    # we need to loop through all ranges
    if ($isBigGroup) {
        $rangeStep = 1499
        $lowRange = 0
        $highRange = $lowRange + $rangeStep
        $last = $false
        $rangeSearchDone = $false

        do {
            $range = $entry.Attributes.AttributeNames | Where-Object { $_ -like "member;range=*" }

            foreach ($member in $entry.Attributes.$range) {
                $memberString = [System.Text.Encoding]::UTF8.GetString($member)

                if ($memberString -like '<TTL=*>,*') {
                    # Get the TTL value from the member attribute
                    # we need to use match to get the value between the '=' and '>' characters
                    $TTL = [regex]::Match($memberString, '<TTL=(\d+)>').Groups[1].Value
        
                    if ($membersAttributes) {
                        Search-LDAPWitLDAPControl -DomainServer $domainServer -DomainDN $domainDN -LdapFilter (distinguishedName=*) -SearchScope $searchScope -LdapControlOID $LDAP_SERVER_LINK_TTL_OID -LdapConnection $ldapConnection
                    }

                    $object = [PSCustomObject][ordered]@{
                        Group               = $entry.DistinguishedName
                        Member              = [regex]::Match($memberString, ',(.+)').Groups[1].Value # suppress the '<TTL=xxx>' part
                        # Get the TTL value from the member attribute
                        # we need to use match to get the value between the '=' and '>' characters
                        TTL                 = $TTL
                        # Calculate the expiration date
                        MembershipExpiresOn = $searchTime.AddSeconds($TTL)
                    }
        
                    $groupsWithExpireLinks.Add($object)
                }
            }

            if ($last) {
                $rangeSearchDone = $true
                break
            }
            # Update the range
            $lowRange = $highRange + 1
            $highRange = $lowRange + $rangeStep

            $ldapFilter = "(distinguishedName=$($entry.distinguishedName))"
            $attributes = "member;range=$LowRange-$HighRange"
            $entriesForThisGroup = Search-LDAPWitLDAPControl -DomainServer $domainServer -DomainDN $domainDN -LdapFilter $ldapFilter -SearchScope $searchScope -Attributes $attributes -LdapControlOID $LDAP_SERVER_LINK_TTL_OID -LdapConnection $ldapConnection
            # Get the current time
            $searchTime = [System.DateTime]::Now

            $entry = $entriesForThisGroup.Entries
            # if $entriesforthisgroup has member;range=xxx-*, it means there are no more range to get
            if ($entriesForThisGroup.Entries.Attributes.AttributeNames -match '\*') {
                $last = $true
            }
        } until ($rangeSearchDone)

        # Set the members to the full list
        $entry.Attributes['member'] = $allMembers
    }
    else {
        foreach ($member in $entry.Attributes['member']) {
            $memberString = [System.Text.Encoding]::UTF8.GetString($member)
            
            if ($memberString -like '<TTL=*>,*') {
                $TTL = [regex]::Match($memberString, '<TTL=(\d+)>').Groups[1].Value
    
                $object = [PSCustomObject][ordered]@{
                    Group               = $entry.DistinguishedName
                    Member              = [regex]::Match($memberString, ',(.+)').Groups[1].Value 
                    TTL                 = $TTL
                    MembershipExpiresOn = $searchTime.AddSeconds($TTL)
                }
    
                $groupsWithExpireLinks.Add($object)
            }
        }
    }
}

if (-not ([string]::IsNullOrWhitespace($membersAttributes))) {
    [System.Collections.Generic.List[PSObject]]$updatedGroupsWithExpireLinks = @()

    foreach ($group in $groupsWithExpireLinks) {
        $member = $group.Member
        $groupObject = Get-ADObject -Identity $group -Properties $groupsAttributes

        foreach ($attribute in $groupsAttributes) {
            $group | Add-Member -MemberType NoteProperty -Name "Group$attribute" -Value $groupObject.$attribute
        }
        
        $updatedGroupsWithExpireLinks.Add($group)
    }

    $groupsWithExpireLinks = $updatedGroupsWithExpireLinks
}


if (-not ([string]::IsNullOrWhitespace($groupsAttributes))) {
    [System.Collections.Generic.List[PSObject]]$updatedGroupsWithExpireLinks = @()

    foreach ($group in $groupsWithExpireLinks) {
        $member = $group.Member
        $groupObject = Get-ADObject -Identity $group.Group -Properties $groupsAttributes

        foreach ($attribute in $groupsAttributes) {
            $group | Add-Member -MemberType NoteProperty -Name "Group_$attribute" -Value $groupObject.$attribute
        }

        $updatedGroupsWithExpireLinks.Add($group)
    }

    $groupsWithExpireLinks = $updatedGroupsWithExpireLinks
}

return $groupsWithExpireLinks