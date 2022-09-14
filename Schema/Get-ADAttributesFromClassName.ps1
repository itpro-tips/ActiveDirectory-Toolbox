# Source https://www.easy365manager.com/how-to-get-all-active-directory-user-object-attributes/
Function Get-ADAttributesFromClassName {
    Param(
        [CmdletBinding()]
    
        [Parameter(Mandatory)]
        [String]$ClassName
    )
    $Loop = $True
    $classArray = New-Object -TypeName 'System.Collections.ArrayList'
    $attributes = New-Object -TypeName 'System.Collections.ArrayList'
    
    # Retrieve the object class and any parent classes
    While ($Loop) {
        $class = Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { ldapDisplayName -Like $ClassName } -Properties AuxiliaryClass, SystemAuxiliaryClass, mayContain, mustContain, systemMayContain, systemMustContain, subClassOf, ldapDisplayName
        If ($class.ldapDisplayName -eq $class.subClassOf) {
            $Loop = $False
        }
        
        $null = $ClassArray.Add($class)
        $ClassName = $class.subClassOf
    }
    # Loop through all the classes and get all auxiliary class attributes and direct attributes
    $ClassArray | ForEach-Object {
        # Get Auxiliary class attributes
        $Aux = $_.AuxiliaryClass | ForEach-Object { 
            Get-ADObject -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { ldapDisplayName -like $_ } -Properties mayContain, mustContain, systemMayContain, systemMustContain } | Select-Object @{n = "Attributes"; e = { $_.mayContain + $_.mustContain + $_.systemMaycontain + $_.systemMustContain } } | Select-Object -ExpandProperty Attributes
        # Get SystemAuxiliary class attributes
        if ($UserClass.SystemAuxiliaryClass.count -ge 1) {
            $SysAux = $UserClass.SystemAuxiliaryClass | ForEach-Object {
                Get-ADObject -ErrorAction SilentlyContinue -SearchBase (Get-ADRootDSE).SchemaNamingContext -Filter { ldapDisplayName -like $_ } -Properties MayContain, SystemMayContain, systemMustContain } | Select-Object @{n = "Attributes"; e = { $_.maycontain + $_.systemmaycontain + $_.systemMustContain } } | Select-Object -ExpandProperty Attributes
        }
        # Get direct attributes
        $attributes += $Aux + $SysAux + $_.mayContain + $_.mustContain + $_.systemMayContain + $_.systemMustContain
    }
    
    return $attributes | Sort-Object | Get-Unique
}