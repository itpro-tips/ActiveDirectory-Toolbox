# source: https://gist.github.com/IISResetMe/399a75cfccabc1a17d0cc3b5ae29f3aa#file-update-msexchstoragegroupschema-ps1

# Dictionary to hold superclass names
$superClass = @{}

# List to hold class names that inherit from container and are allowed to live under computer object
$vulnerableSchemas = [System.Collections.Generic.List[string]]::new()

# Resolve schema naming context
$schemaNC = (Get-ADRootDSE).schemaNamingContext

# Enumerate all class schemas
$classSchemas = Get-ADObject -LDAPFilter '(objectClass=classSchema)' -SearchBase $schemaNC -Properties lDAPDisplayName,subClassOf,possSuperiors

# Enumerate all class schemas that computer is allowed to contain
$computerInferiors = $classSchemas |Where-Object possSuperiors -eq 'computer'

# Populate superclass table
$classSchemas |ForEach-Object {
    $superClass[$_.lDAPDisplayName] = $_.subClassOf
}

# Resolve class inheritance for computer inferiors
$computerInferiors |ForEach-Object {
  $class = $cursor = $_.lDAPDisplayName
  while($superClass[$cursor] -notin 'top'){
    if($superClass[$cursor] -eq 'container'){
      $vulnerableSchemas.Add($class)
      break
    }
    $cursor = $superClass[$cursor]
  }
}

# Outpupt list of vulnerable class schemas 
$vulnerableSchemas