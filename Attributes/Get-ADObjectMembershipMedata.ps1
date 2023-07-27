# we can also use Get-ADReplicationAttributeMetadata 'dn' -Server VYGECOADY01PWV -ShowAllLinkedValues -Filter {isLinkValue -eq $true} | Out-GridView

Function Get-ADGroupMembershipMetadata {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [String] $GroupDN
    )

    try {
        $null = Import-Module ActiveDirectory
    }
    catch {
        Write-Warning 'Unable to load ActiveDirectory module'
        return
    }

    [System.Collections.Generic.List[PSObject]] $objectMetadataArray = @()

    $group = Get-ADObject $GroupDN -Properties 'msDS-ReplValueMetaData'
    $replValueMetaData = $Group.'msDS-ReplValueMetaData'
    $replValueMetaData = '<root>' + $ReplValueMetaData + '</root>'
    $replValueMetaData = $ReplValueMetaData.Replace([char]0, ' ')
    $replValueMetaData = [XML]$ReplValueMetaData
    $replValueMetaData = $ReplValueMetaData.root.DS_REPL_VALUE_META_DATA
    
    $replValueMetaData | ForEach-Object {

        $object = [PSCustomObject][ordered]@{
            ObjectDN                  = $_.pszObjectDn
            TimeCreated               = $_.ftimeCreated
            TimeDeleted               = $_.ftimeDeleted
            Version                   = $_.dwVersion
            TimeLastOriginatingChange = $_.ftimeLastOriginatingChange
            LastOriginatingDsaDN      = $_.pszLastOriginatingDsaDN
        }

        $objectMetadataArray.Add($object)
    }

    $groupMembershipMetadataArray = [PSCustomObject][ordered]@{
        ObjectDN = $GroupDN
        Members  = $objectMetadataArray
    }

    return $groupMembershipMetadataArray
}