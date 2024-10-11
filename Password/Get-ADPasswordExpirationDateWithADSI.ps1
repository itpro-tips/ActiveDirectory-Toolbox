function Get-PasswordExpirationDate {
    param (
        [string]$SamAccountName,
        [ValidateSet('Users', 'Computers', 'All')]
        [string]$ObjectType = 'Users'
    )

    # Create a new DirectorySearcher object to query Active Directory
    $searcher = New-Object DirectoryServices.DirectorySearcher

    # Set the filter based on the type parameter
    switch ($ObjectType) {
        'users' {
            $filter = '(&(objectCategory=person)(objectClass=user)'
        }
        'computers' {
            $filter = '(&(objectCategory=computer)'
        }
        'all' {
            $filter = '(&(|(objectCategory=person)(objectCategory=computer))'
        }
    }

    # Add the sAMAccountName filter if provided
    if ($samaccountname) {
        $filter += "(sAMAccountName=$samaccountname))"
    }
    else {
        $filter += ')'
    }

    $searcher.Filter = $filter

    # Specify the properties to load: msDS-UserPasswordExpiryTimeComputed and sAMAccountName
    $null = $searcher.PropertiesToLoad.Add('msDS-UserPasswordExpiryTimeComputed')
    $null = $searcher.PropertiesToLoad.Add('sAMAccountName')

    # Execute the search and get the results
    $results = $searcher.FindAll()

    # Initialize the array to store results
    [System.Collections.Generic.List[Object]]$objectsArray = @()

    # Iterate through the results and add them to the array
    foreach ($result in $results) {
        $expiryTime = $result.Properties['msDS-UserPasswordExpiryTimeComputed']

        $object = [PSCustomObject][ordered]@{
            sAMAccountName = $result.Properties['sAMAccountName'][0]
            PasswordExpiry = if ($expiryTime -and $expiryTime[0] -gt 0) {
                try {
                    [DateTime]::FromFileTime([Int64]$expiryTime[0])
                }
                catch {
                    'Invalid FileTime (Never expires)'
                }
            }
            else {
                'Not Set'
            }
        }

        $objectsArray.Add($object)
    }

    # Dispose of the searcher object to free resources
    $searcher.Dispose()

    # Return the array
    return $objectsArray
}