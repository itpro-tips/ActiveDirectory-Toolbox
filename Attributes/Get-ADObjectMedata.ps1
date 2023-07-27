# Get-ADObjectMetadata 'DN' -Attributes ObjectClass,sn, cn
# we can also use Get-ADReplicationAttributeMetadata 'xxxx' -Server xxx
function Get-ADObjectMetadata {
    Param(
        [Parameter(Mandatory = $true)]
        [String] $ObjectDN,
        [Parameter(Mandatory = $false)]
        [String[]] $Attributes
    )

    try {
        $null = Import-Module ActiveDirectory
    }
    catch {
        Write-Warning 'Unable to load ActiveDirectory module'
        return
    }

    [System.Collections.Generic.List[PSObject]] $objectMetadataArray = @()

    $adObject = Get-ADObject $ObjectDN -Properties 'msDS-ReplAttributeMetaData'
    $replAttributeMetaData = $adObject.'msDS-ReplAttributeMetaData'
    $replAttributeMetaData = '<root>' + $ReplAttributeMetaData + '</root>'
    $replAttributeMetaData = $ReplAttributeMetaData.Replace([char]0, ' ')
    $replAttributeMetaData = [XML]$ReplAttributeMetaData
    $replAttributeMetaData = $ReplAttributeMetaData.root.DS_REPL_ATTR_META_DATA

    # get only attributes that are specified
    if ($Attributes) {
        foreach ($attribute in $attributes) {
            $attributeMetadata = $replAttributeMetaData | Where-Object { $_.pszAttributeName -eq $attribute }

            $object = [PSCustomObject][ordered]@{
                AttributeName             = $attributeMetadata.pszAttributeName
                Version                   = $attributeMetadata.dwVersion
                TimeLastOriginatingChange = $attributeMetadata.ftimeLastOriginatingChange
                usnOriginatingChange      = $attributeMetadata.usnOriginatingChange
                usnLocalChange            = $attributeMetadata.usnLocalChange
                LastOriginatingDsaDN      = $attributeMetadata.pszLastOriginatingDsaDN
            }

            $objectMetadataArray.Add($object)
        }
    }
    else {
        $replAttributeMetaData | ForEach-Object {

            $object = [PSCustomObject][ordered]@{
                AttributeName             = $_.pszAttributeName
                Version                   = $_.dwVersion
                TimeLastOriginatingChange = $_.ftimeLastOriginatingChange
                usnOriginatingChange      = $_.usnOriginatingChange
                usnLocalChange            = $_.usnLocalChange
                LastOriginatingDsaDN      = $_.pszLastOriginatingDsaDN
            }

            $objectMetadataArray.Add($object)
        }
    }

    return $objectMetadataArray
}