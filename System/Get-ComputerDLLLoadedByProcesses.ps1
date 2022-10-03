function Get-ComputerDLLLoadedByProcesses {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$ComputerName,
        [Parameter(Mandatory = $false)]
        [String]$ProcessName
    )
    
    [System.Collections.Generic.List[PSObject]]$dllArray = @()

    if ($ProcessName) {
        if ($computerName) {
            $allProcesses = Get-Process -ComputerName $ComputerName -ProcessName $ProcessName
        }
        else {
            $computerName = $env:COMPUTERNAME
            $allProcesses = Get-Process -ProcessName $ProcessName
        }
    }
    else {
        if ($computerName) {
            $allProcesses = Get-Process -ComputerName $ComputerName
        }
        else {
            $computerName = $env:COMPUTERNAME
            $allProcesses = Get-Process
        }
    }    

    foreach ($process in $allProcesses) {
        foreach ($module in $process.modules) {

            $object = [PSCustomObject][ordered]@{
                ComputerName         = $ComputerName
                Process              = $process.Name
                ProcessID            = $process.ID
                ModuleName           = $module.ModuleName
                ModuleFileName       = $module.FileName
                ModuleSize           = $module.Size
                ModuleDescription    = $module.Description
                ModuleProduct        = $module.Product
                ModuleProductVersion = $module.ProductVersion
            }

            $dllArray.Add($object)
        }
    }

    return $dllArray
}