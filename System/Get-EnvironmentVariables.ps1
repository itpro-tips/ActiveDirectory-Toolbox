function Get-EnvironmentVariables {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String[]]$ComputerName
    )

    [System.Collections.Generic.List[PSObject]]$environmentVariablesArray = @()

    $environmentVariables = Invoke-Command -ComputerName $ComputerName { Get-ChildItem env: }
  
    $defaultEnvironmentVariables = @(
        'ALLUSERSPROFILE',
        'APPDATA',
        'CommonProgramFiles',
        'CommonProgramFiles(x86)',
        'CommonProgramW6432',
        'COMPUTERNAME',
        'ComSpec',
        'HOMEDRIVE',
        'HOMEPATH',
        'LOCALAPPDATA',
        'LOGONSERVER',
        'NUMBER_OF_PROCESSORS',
        'OS',
        'Path',
        'PATHEXT',
        'PROCESSOR_ARCHITECTURE',
        'PROCESSOR_IDENTIFIER',
        'PROCESSOR_LEVEL',
        'PROCESSOR_REVISION',
        'ProgramData',
        'ProgramFiles',
        'ProgramFiles(x86)',
        'ProgramW6432',
        'PSModulePath',
        'PUBLIC',
        'SystemDrive',
        'SystemRoot',
        'TEMP',
        'TMP',
        'USERDNSDOMAIN',
        'USERDOMAIN',
        'USERDOMAIN_ROAMINGPROFILE',
        'USERNAME',
        'USERPROFILE',
        'windir'
    )
  
    foreach ($environmentVariable in $environmentVariables) {
        $object = [PSCustomObject][ordered] @{
            Computer                      = $Computer
            EnvironmentVariable           = $environmentVariable.Name
            EnvironmentVariableValue      = $environmentVariable.Value
            IsADefaultEnvironmentVariable = if ($defaultEnvironmentVariables -contains $environmentVariable.Name) { $true }else { $false }
        }
  
        $environmentVariablesArray.Add($object)
    }

    return $environmentVariablesArray
}