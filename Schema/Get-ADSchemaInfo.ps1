function Get-ADSchemaInfo {
    Param(
        [CmdletBinding()]
    
        [Parameter(Mandatory = $false)]
        [String]$Attribute
    )

    $rootDSE = [adsi]"LDAP://RootDSE"
    $schemaNS = $rootDSE.schemaNamingContext.Value
    [System.Collections.Generic.List[PSObject]] $schemaInfo = @()
    [System.Collections.Generic.List[PSObject]] $schemaInfoFormatted = @()

    if ($attribute) {
        $filter = "lDAPDisplayName -eq '$($attribute)'"
    }
    else {
        $filter = '*'
    }

    Get-ADObject -SearchBase $schemaNS -Filter $filter -properties ldapDisplayName, adminDescription, adminDisplayName, CN, attributeId, isSingleValued, attributeSyntax, systemOnly, linkId, isDeleted, rangeLower, rangeUpper, searchFlags, whenCreated, whenChanged, searchFlags  | ForEach-Object {
        $schemaInfo.Add($_)
    }

    # check if attribute is member of Partial Attribute Set (used in Global Catalog)
    $attributesInPas = Get-ADObject -SearchBase $schemaNS -LDAPFilter "(&(objectCategory=attributeSchema)(isMemberOfPartialAttributeSet=TRUE))" -Properties lDAPDisplayName | Select-Object lDAPDisplayName

    foreach ($att in $schemaInfo) {

        $object = [PSCustomObject][ordered]@{
            adminDisplayName              = $att.adminDisplayName
            attributeId                   = $att.attributeId
            attributeSyntax               = $att.attributeSyntax
            CN                            = $att.CN
            DistinguishedName             = $att.DistinguishedName
            isMemberOfPartialAttributeSet = $null
            isSingleValued                = $att.isSingleValued
            ldapDisplayName               = $att.lDAPDisplayName
            Name                          = $att.Name
            ObjectClass                   = $att.ObjectClass
            ObjectGUID                    = $att.ObjectGUID
            rangeLower                    = $att.rangeLower
            rangeUpper                    = $att.rangeUpper
            searchFlags                   = $att.searchFlags
            whenChanged                   = $att.whenChanged
            whenCreated                   = $att.whenCreated
            adminDescription              = $att.adminDescription
            RODCenabled                   = $null
            AttributeAuditing             = $null
            Confidential                  = $null
            SubtreeIndexing               = $null
            ToupleIndexing                = $null
            CopyonCopy                    = $null
            PreserveonDelete              = $null
            ANR                           = $null
            ContainerIndexing             = $null
            Indexed                       = $null
        }

        if ($object.ObjectClass -eq 'attributeSchema') {
            if ($object.lDAPDisplayName -in $attributesInPas.lDAPDisplayName) {
                $object.IsMemberOfPartialAttributeSet = $true
            }
            else {
                $object.IsMemberOfPartialAttributeSet = $false
            }

            [int]$searchflagsInt = $object.searchflags.ToString()

            <#
        = 1    # Set indexing for attribute
        = 2    # Set indexing per container, for one-level searches of a container with children
        = 4    # Set Ambiguous Name Resolution (ANR) for the attribute
        = 8    # Preserve attribute on deletion
        = 16   # Copy attribute when object is copied
        = 32   # Enable Touple indexing for attribute
        = 64   # Create subtree index
        = 128  # Confidential, will trigger an exception from object.setInfo() for some reason. Flag is set anyway
        = 256  # Enable auditing on attribute, setting bit disables auditing
        = 512  # Put attribute in filtered attribute set, used to exclude this attribute from being replicated to RODCs
        #>
            While ($searchflagsInt -gt 0) {
                switch ($searchflagsInt) {
                    { $_ -ge 512 } { $searchflagsInt = $searchflagsInt - 512; $object.RODCenabled = $true; break }
                    { $_ -ge 256 } { $searchflagsInt = $searchflagsInt - 256; $object.AttributeAuditing = $true; break }
                    { $_ -ge 128 } { $searchflagsInt = $searchflagsInt - 128; $object.Confidential = $true; break }
                    { $_ -ge 64 } { $searchflagsInt = $searchflagsInt - 64; $object.SubtreeIndexing = $true; break }
                    { $_ -ge 32 } { $searchflagsInt = $searchflagsInt - 32; $object.ToupleIndexing = $true; break }
                    { $_ -ge 16 } { $searchflagsInt = $searchflagsInt - 15; $object.CopyonCopy = $true; break }
                    { $_ -ge 8 } { $searchflagsInt = $searchflagsInt - 8; $object.PreserveonDelete = $true; break }
                    { $_ -ge 4 } { $searchflagsInt = $searchflagsInt - 4; $object.ANR = $true; break }
                    { $_ -ge 2 } { $searchflagsInt = $searchflagsInt - 2; $object.ContainerIndexing = $true; break }
                    { $_ -ge 1 } { $searchflagsInt = $searchflagsInt - 1; $object.indexed = $true; break } 
                }
            }
        }
        
        $schemaInfoFormatted.Add($object)
    }

    return $schemaInfoFormatted
}