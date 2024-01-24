# Declare a generic list to store results
[System.Collections.Generic.List[PSObject]] $sidObjectsArray = @()

# Get all objects with non-empty SIDHistory attribute and include properties sIDHistory,msDS-ReplattributeMetaData,samaccountname
Get-ADobject -LDAPFilter "(sidHistory=*)" -Properties sIDHistory, distinguishedName, samaccountname, 'msDS-ReplattributeMetaData' | ForEach-Object { 
    # Get the last change date of the SIDHistory attribute
    $replattributeMetaData = $_.'msDS-ReplattributeMetaData'
    $replattributeMetaData = '<root>' + $replattributeMetaData + '</root>'
    $replattributeMetaData = $replattributeMetaData.Replace([char]0, ' ')
    $replattributeMetaData = [XML]$replattributeMetaData
    $replattributeMetaData = $replattributeMetaData.root.DS_REPL_ATTR_META_DATA
    $replattributeMetaData = $replattributeMetaData | Where-Object { $_.pszattributeName -eq 'sIDHistory' } | Select-Object -ExpandProperty ftimeLastOriginatingChange
    $lastChangeDate = $replattributeMetaData | Get-Date -Format 'MM/dd/yyyy'
    
    # create an ordered PSCustomObject to hold the properties of the object
    $object = [PSCustomObject][ordered]@{
        SamAccountName    = $_.samAccountName
        SIDHistory        = $_.sIDHistory
        LastChangeDate    = $lastChangeDate
        DistinguishedName = $_.distinguishedName
    }

    $sidObjectsArray.Add($object)
}

# display the list content
$sidObjectsArray