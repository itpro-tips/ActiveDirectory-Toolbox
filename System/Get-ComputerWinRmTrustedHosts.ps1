
<#
    .SYNOPSIS
    Get trusted hosts (WinRM)

    .DESCRIPTION
    Get trusted hosts (WinRM).

    .EXAMPLE
    Get-TrustedHost

    TrustedHost
    -----------
    192.168.59.15
    10.10.10.
    Windows11_test

    Inspired by https://raw.githubusercontent.com/BornToBeRoot/PowerShell/master/Module/LazyAdmin/Functions/TrustedHost/Get-TrustedHost.ps1
#>
function Get-ComputerWinRmTrustedHosts {
    [CmdletBinding()]
    param(
        [String]$ComputerName
    )
    
    [System.Collections.Generic.List[PSObject]]$trustedHostsArray = @()

    $trustedHostsPath = 'WSMan:\localhost\Client\TrustedHosts'

    if ($ComputerName) {
        $trustedHosts = Invoke-Command -ComputerName $ComputerName { (Get-Item -Path $args[0]).Value } -ArgumentList $trustedHostsPath
    }
    else {
        $computerName = $env:COMPUTERNAME
        $trustedHosts = (Get-Item -Path $trustedHostsPath).Value 
    }

    if ([String]::IsNullOrEmpty($trustedHosts)) {            
        $object = [PSCustomObject][ordered]@{
            ComputerName = $ComputerName
            TrustedHost  = '-'
        }

        $trustedHostsArray.Add($object)
    }
    else {
        foreach ($trustedHost in $trustedHosts.Split(',')) {
        
            $object = [PSCustomObject][ordered]@{
                ComputerName = $ComputerName
                TrustedHost  = $trustedHost
            }
        
            $trustedHostsArray.Add($object)
        }                                    
    }

    return $trustedHostsArray    
}