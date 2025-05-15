<#
.SYNOPSIS
    Retrieves information about Active Directory schema classes and attributes.

.DESCRIPTION
    The Get-ADAttributeInfo function provides detailed information about Active Directory schema classes and attributes.
    It can be used in two modes:
    1. Class mode: Get information about all mandatory and optional attributes in a specific class
    2. Attribute mode: Get information about a specific attribute and all classes using it

.PARAMETER FromClass
    Specifies the Active Directory schema class name to retrieve information about.

.PARAMETER AttributeName
    Specifies the Active Directory attribute name to retrieve information about.

.EXAMPLE
    Get-ADAttributeInfo -FromClass "user"
    
    Returns a list of all mandatory and optional properties for the "user" class.

.EXAMPLE
    Get-ADAttributeInfo -AttributeName "mail"
    
    Returns a list of all classes that use the "mail" attribute, and whether it's mandatory or optional in each class.

.EXAMPLE
    $userProperties = Get-ADAttributeInfo -FromClass "user"
    $userProperties | Where-Object { $_.Type -eq 'Mandatory' }
    
    Gets all properties for the "user" class and then filters to show only mandatory ones.

.EXAMPLE
    Get-ADAttributeInfo -AttributeName "displayName" | Format-Table
    
    Gets all classes that use the "displayName" attribute and formats the output as a table.

.NOTES
    This function requires access to the Active Directory schema.
#>
function Get-ADAttributeInfo {
    [CmdletBinding(DefaultParameterSetName = 'Attribute')]
    Param
    (
        [Parameter(Mandatory = $false, ParameterSetName = 'Attribute', Position = 0)]
        [string]$AttributeName,
        [Parameter(Mandatory = $true, ParameterSetName = 'Class')]
        [string]$FromClass
    )
 
    $schema = [System.DirectoryServices.ActiveDirectory.ActiveDirectorySchema]::GetCurrentSchema()
 
    if ($PSCmdlet.ParameterSetName -eq 'Class') {
        try {
            $classObject = $schema.FindClass($FromClass)
            
            # Create a list to store properties
            [System.Collections.Generic.List[Object]]$propertiesList = @()

            # Add mandatory properties to the list
            foreach ($property in ($classObject.MandatoryProperties | Sort-Object)) {
                $null = $propertiesList.Add([PSCustomObject]@{
                        Property = $property
                        Type     = 'Mandatory'
                    })
            }

            # Add optional properties to the list
            foreach ($property in ($classObject.OptionalProperties | Sort-Object)) {
                $null = $propertiesList.Add([PSCustomObject]@{
                        Property = $property
                        Type     = 'Optional'
                    })
            }

            # Return the list of properties
            return $propertiesList
        }
        catch {
            Write-Error "Class '$FromClass' not found or error accessing schema information: $_"
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Attribute') {
        try {
            $attributeObject = $schema.FindProperty($AttributeName)
            
            # Create a list to store classes that use this attribute
            [System.Collections.Generic.List[Object]]$classesList = @()
            
            # Loop through schema classes and check if they contain the attribute
            foreach ($class in $schema.FindAllClasses()) {
                if (($class.MandatoryProperties.Name -contains $AttributeName) -or ($class.OptionalProperties.Name -contains $AttributeName)) {
                    $object = [PSCustomObject][ordered]@{
                        Class       = $class.Name
                        Attribute   = $AttributeName
                        IsMandatory = if ($class.MandatoryProperties.Name -contains $AttributeName) { $true } elseif ($class.OptionalProperties.Name -contains $AttributeName) { $false } else { '-' }
                    }
                    
                    $classesList.Add($object)
                }
            }
            
            # Return the list of classes
            return $classesList
        }
        catch {
            Write-Error "Attribute '$AttributeName' not found or error accessing schema information: $_"
        }
    }
    else {
        Write-Error 'You must specify either -FromClass or -AttributeName parameter.'
    }
    
    return
}