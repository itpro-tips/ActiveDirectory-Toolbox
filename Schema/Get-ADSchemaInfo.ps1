function Get-ADAttributeInfo {
    Param(
        [CmdletBinding()]
    
        [Parameter(Mandatory = $false)]
        [String]$Attribute
    )

    $rootDSE = [adsi]"LDAP://RootDSE"
    $schemaNS = $rootDSE.schemaNamingContext.Value
    [System.Collections.Generic.List[PSObject]] $attributesInfo = @()

    # Get all AD attributes
    if (-not $attribute) {
        # IsMemberOfPartialAttributeSet is empty but will be used after in this scrip
        Get-ADObject -SearchBase $schemaNS -Filter * -properties ldapDisplayName, attributeId, isSingleValued, attributeSyntax, systemOnly, linkId, isDeleted, rangeLower, rangeUpper, whenCreated, whenChanged, IsMemberOfPartialAttributeSet | ForEach-Object {
            $attributesInfo.Add($_)
        }
    }
    else {
        Get-ADObject -SearchBase $schemaNS -Filter { lDAPDisplayName -eq $attribute } -properties ldapDisplayName, attributeId, isSingleValued, attributeSyntax, systemOnly, linkId, isDeleted, rangeLower, rangeUpper, whenCreated, whenChanged, IsMemberOfPartialAttributeSet  | ForEach-Object {
            $attributesInfo.Add($_)
        }
    }

    # check if attribute is member of Partial Attribute Set (used in Global Catalog)
    $attributesInPas = Get-ADObject -SearchBase $schemaNS -LDAPFilter "(&(objectCategory=attributeSchema)(isMemberOfPartialAttributeSet=TRUE))" -Properties lDAPDisplayName | Select-Object lDAPDisplayName

    [System.Collections.Generic.List[PSObject]] $attributesMap = @()

    foreach ($att in $attributesInfo) {

        $object = $att

        if ($att.lDAPDisplayName -in $attributesInPas.lDAPDisplayName) {
            $object.IsMemberOfPartialAttributeSet = $true    
        }
        else {
            $object.IsMemberOfPartialAttributeSet = $false
        }

        $attributesMap.Add($object)

    }

    return $attributesMap
}