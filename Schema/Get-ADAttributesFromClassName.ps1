# modified version of https://www.easy365manager.com/how-to-get-all-active-directory-user-object-attributes/
Function Get-ADAttributesFromClassName {
    Param(
        [CmdletBinding()]
        [Parameter(Mandatory = $true)]
        [String]$ClassName
    )

    $loop = $True
    [System.Collections.Generic.List[PSObject]]$classArray = @()
    [System.Collections.Generic.List[PSObject]]$attributesArray = @()
    
    # Retrieve the object class and any parent classes
    
    while ($loop) {
        $class = Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { ldapDisplayName -Like $ClassName } -Properties AuxiliaryClass, SystemAuxiliaryClass, mayContain, mustContain, systemMayContain, systemMustContain, subClassOf, ldapDisplayName
        
        if ($class.ldapDisplayName -eq $class.subClassOf) {
            $loop = $False
        }
        
        $null = $ClassArray.Add($class)

        $ClassName = $class.subClassOf
    }
    
    # Loop through all the classes and get all auxiliary class attributes and direct attributes
    $ClassArray | ForEach-Object {

        # Get Auxiliary class attributes
        $auxiliaryClass = $_.AuxiliaryClass | ForEach-Object { 
            Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { ldapDisplayName -like $_ } -Properties mayContain, mustContain, systemMayContain, systemMustContain } | Select-Object @{Name = 'Attributes'; Expression = { $_.mayContain + $_.mustContain + $_.systemMaycontain + $_.systemMustContain } } | Select-Object -ExpandProperty Attributes
        
        # Get SystemAuxiliary class attributes
        if ($UserClass.SystemAuxiliaryClass.count -ge 1) {
            $SystemAuxiliaryClass = $UserClass.SystemAuxiliaryClass | ForEach-Object {
                Get-ADObject -ErrorAction SilentlyContinue -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { ldapDisplayName -like $_ } -Properties MayContain, SystemMayContain, systemMustContain } | Select-Object @{Name = 'Attributes'; Expression = { $_.maycontain + $_.systemmaycontain + $_.systemMustContain } } | Select-Object -ExpandProperty Attributes
        }

        # Get direct attributes
        $attributesArray.Add($auxiliaryClass + $SystemAuxiliaryClass + $_.mayContain + $_.mustContain + $_.systemMayContain + $_.systemMustContain)
    }
    
    return $attributesArray | Sort-Object | Get-Unique
}