#Requires -Modules ActiveDirectory

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())

<#
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please launch the script in admin mode. Exiting..."
    return 1
}
#>

$schema = (Get-ADRootDSE).schemaNamingContext
$schemaMaster = ([System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()).SchemaRoleOwner
$config = (Get-ADRootDSE).configurationNamingContext

function Check-ADRights {
    Param (
        [string[]]$AttributeDN
    )
    
    $netBIOSName = (Get-ADDomain).NetBIOSName
    $identities = (Get-ACL -Path "AD:$attributeDN" | Select-Object -ExpandProperty access | Where-Object { $_.ActiveDirectoryRights -like '*WriteProperty*' }).IdentityReference

    $hasRights = $false

    foreach ($identity in $identities.Value) {
        $type = $null
        $res = $null

        # identity is DOMAIN\samaccountname. We have to remove DOMAIN\. \\ to not be consider as regex
        $identityFormatted = $identity -replace ($netBIOSName + '\\'), ''
    
        $type = (Get-ADObject -Filter "samaccountname -eq '$($identityFormatted)'" -Server $schemaMaster).ObjectClass

        # if group has rights on the attribute, we found if the current user is a member of this group (in the Kerberos token)
        if ($type -eq 'group') {
            # The group membership checking is not realize against AD group because it is not relecting the current right of the user.
            # Instead we check the group membership in the Kerberos token to be more accurate
            # source : https://activedirectoryfaq.com/2016/08/read-kerberos-token-powershell/
            $groupMembership = (([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups).Translate([System.Security.Principal.NTAccount])

            $res = $groupMembership -contains $identity
        }
        else {
            $res = $env:USERNAME -eq $identity
        }

        if ($res) {
            $hasRights = $true
        }
    }

    return $hasRights
}

function Get-ADPropertySet {
    param (
        [Parameter(Mandatory = $false)]
        [string]$PropertySetName,
        [Parameter(Mandatory = $false)]
        [switch]$DoNoIncludeAttributes
    )

    # List all Property Sets and their attributes
    [System.Collections.Generic.List[PSObject]] $propertySetArray = @()

    if ($PropertySetName) {
        $filter = "rightsGuid -like '*' -and Name -like '$PropertySetName'"
    }
    else {
        $filter = "rightsGuid -like '*'"
    }
    
    # extendedRight is a controlAccessRight with validAccesses = 0x30 (48)
    $propertySets = @(Get-ADObject -Filter $filter -SearchBase "CN=Extended-Rights,$config" -Properties rightsGuid, validAccesses | Where-Object { $_.validAccesses -eq 48 })

    if ($propertySets.Count -eq 0) {
        Write-Warning "No Property Set $PropertySetName found"
        return $null
    }

    if ($DoNoIncludeAttributes) {
        foreach ($propertySet in $propertySets) {
            $object = [PSCustomObject][ordered]@{
                PropertySetName = $propertySet.Name
                PropertySetDN   = $propertySet.DistinguishedName
                PropertySetGUID = $propertySet.ObjectGUID
            }

            $propertySetArray.Add($object)
        }
    }
    else {
        # get all AD attributes for each property set
        foreach ($propertySet in $propertySets) {

            $guid = [guid]$propertySet.rightsGuid
            $guidByteArray = $guid.ToByteArray()

            $properties = Get-ADObject -Filter { attributeSecurityGUID -eq $guidByteArray } -SearchBase $schema -Properties *

            foreach ($property in $properties) {
                $object = [PSCustomObject][ordered]@{
                    PropertySetName           = $propertySet.Name
                    PropertySetDN             = $propertySet.DistinguishedName
                    PropertySetGUID           = $propertySet.ObjectGUID
                    AttributeName             = $property.Name
                    AttributeLDAPDisplayName  = $property.lDAPDisplayName
                    AttributeAdminDescription = $property.adminDescription
                    AttributeAdminDisplayName = $property.adminDisplayName
                    AttributeDN               = $property.DistinguishedName
                }

                $propertySetArray.Add($object)
            }
        }
    }

    return $propertySetArray
}

function Get-ADPropertySetForAttribute {
    Param
    (
        [Parameter(Mandatory = $true)]
        [string]$ADAttribute
    )

    $property = $null
    $propertySetName = $null

    try {
        $property = Get-ADObject -Filter { Name -eq $ADAttribute -or lDAPDisplayName -eq $ADAttribute } -SearchBase $schema -Properties * -ErrorAction Stop
    }
    catch {
        Write-Warning $_.Exception.Message
    }
    if ($property) {
        if ($property.attributeSecurityGUID) {
            if (Check-ADRights -AttributeDN $property.DistinguishedName) {
                $propertySetGUID = New-Object Guid @(, $property.attributeSecurityGUID)

                # The Property Set are in "CN=Extended-Rights,CN=configuration,DC=domain,DC=com"
                $propertySet = Get-ADObject -filter { rightsGuid -eq $propertySetGUID } -SearchBase "CN=Extended-Rights,$config"
                
                $object = [PSCustomObject]@{
                    AttributeName             = $property.Name
                    AttributeLDAPDisplayName  = $property.lDAPDisplayName
                    AttributeAdminDescription = $property.adminDescription
                    AttributeAdminDisplayName = $property.adminDisplayName
                    AttributeDN               = $property.DistinguishedName
                    PropertySetDN             = $propertySet.DistinguishedName
                    PropertySetName           = $propertySet.Name
                    PropertySetGUID           = $propertySet.ObjectGUID
                }
            }
            else {
                Write-Warning "Current user $env:UserName has not the ModifyProperty Rights to modify $property. Please add rights to this attribute, by example by adding him to Schema Admins group and refresh the Kerberos ticket by logoff/login."
            }
        }
        else {
            Write-Host -ForegroundColor Yellow "IGNORED: $property not part of any Property Set"

        }
    }
    else {
        Write-Warning "$ADProperty attribute not exists"
    }

    return $object
}

function Remove-ADAttributeFromPropertySet {
    Param(
        [Parameter(Mandatory = $true)]
        [string[]]$ADProperties,
        [switch]$Simulation
    )

    foreach ($ADProperty in $ADProperties) {
        $attribute = Get-ADPropertySetForAttribute -ADattribute $ADProperty

        if ($null -ne $attribute) {
            if ($Simulation) {
                Write-Host -ForegroundColor Green "SIMULATION: Remove attribute '$($attribute.Name)' from $($attribute.PropertySetDN) ($($attribute.PropertySetGuid))"
            }
            else {
                try {
                    Set-ADObject $attribute.AttributeDN -Clear attributeSecurityGUID -ErrorAction Stop
                    Write-Host -ForegroundColor Green "Attribute '$($attribute.Name)' removed from $($attribute.PropertySetDN) ($($attribute.PropertySetGuid))"
                }
                catch {
                    Write-Warning $_.Exception.Message
                }
            }
        }
    }
}