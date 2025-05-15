# https://devblogs.microsoft.com/scripting/powershell-and-the-active-directory-schema-part-2/

function New-AttributeOID {
    $prefix = '1.2.840.113556.1.8000.2554'
    $GUID = [System.Guid]::NewGuid().ToString()
    $parts = @()
    $parts += [UInt64]::Parse($guid.SubString(0, 4), 'AllowHexSpecifier')
    $parts += [UInt64]::Parse($guid.SubString(4, 4), 'AllowHexSpecifier')
    $parts += [UInt64]::Parse($guid.SubString(9, 4), 'AllowHexSpecifier')
    $parts += [UInt64]::Parse($guid.SubString(14, 4), 'AllowHexSpecifier')
    $parts += [UInt64]::Parse($guid.SubString(19, 4), 'AllowHexSpecifier')
    $parts += [UInt64]::Parse($guid.SubString(24, 6), 'AllowHexSpecifier')
    $parts += [UInt64]::Parse($guid.SubString(30, 6), 'AllowHexSpecifier')
    $oid = [String]::Format('{0}.{1}.{2}.{3}.{4}.{5}.{6}.{7}', $prefix, $parts[0], $parts[1], $parts[2], $parts[3], $parts[4], $parts[5], $parts[6])

    return $oid
}