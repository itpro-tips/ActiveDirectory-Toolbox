#Requires -Version 4.0
#Requires -RunAsAdministrator

Function Get-SystemInformation {
    Param
    (
        [boolean] $DomainControllers,
        [string[]] $ComputerName 
    )

    Function Get-RegistryValue {
        # Gets the specified registry value or $Null if it is missing
        [CmdletBinding()]
        Param
        (
            [String] $path, 
            [String] $name, 
            [String] $ComputerName
        )

        if ($ComputerName -eq $env:computername -or $ComputerName -eq "LocalHost") {
            $key = Get-Item -LiteralPath $path -EA 0
            if ($key) {
                return $key.GetValue($name, $Null)
            }
            else {
                return $Null
            }
        }

        #path needed here is different for remote registry access
        $path1 = $path.SubString( 6 )
        $path2 = $path1.Replace( '\', '\\' )

        $registry = $null
        try {
            ## use the Remote Registry service
            $registry = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
                [Microsoft.Win32.RegistryHive]::LocalMachine,
                $ComputerName ) 
        }
        catch {
            $e = $error[ 0 ]
            wv "Could not open registry on computer $ComputerName ($e)"
        }

        $val = $null
        if ($registry) {
            $key = $registry.OpenSubKey( $path2 )
            if ($key) {
                $val = $key.GetValue( $name )
                $key.Close()
            }

            $registry.Close()
        }

        return $val
    }

    if (-not (Get-InstalledModule GetSystemInfo -ErrorAction SilentlyContinue)) {
        Write-Warning 'Please install GetSystemInfo first: Install-Module GetSystemInfo'
        return
    }

    if ($DomainControllers) {
        $ComputerName = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
    }
    elseif (-not $ComputerName) {
        $ComputerName = $env:COMPUTERNAME
    }

    $collection = New-Object System.Collections.ArrayList

    foreach ($computer in $ComputerName) {
    
        Write-Host "Processing $computer" -ForegroundColor Cyan

        try {
            $systemInfos = Get-SystemInfo -ComputerName $computer -ErrorAction Stop
        }
        catch {
            Write-Warning "$computer - Get-SystemInfo - $($_.Exception.Message)"
        }

        try {
            $systemInfos = Get-WmiObject -computername $computer Win32_LogicalDisk -ErrorAction Stop
        }
        catch {
            Write-Warning "$computer - Get-WmiObject -computername $computer Win32_LogicalDisk - $($_.Exception.Message)"
        }

        try {
            $drives = Get-SystemSoftware -ComputerName $computer -ErrorAction Stop
        }
        catch {
            Write-Warning "$computer - Get-SystemSoftware - $($_.Exception.Message)"
        }
        
        if ($systemInfos) {
            $object = New-Object -TypeName PSObject -Property ([ordered]@{
                    ComputerName     = $Computer.ToUpper()
                    OperatingSystem  = "$($systemInfos.OperatingSystem) - $($systemInfos.OSArchitecture) - Build:$($systemInfos.OSBuild)"
                    LoggedInUsers    = $systemInfos.LoggedInUsers
                    ComputerIsLocked = $systemInfos.ComputerIsLocked
                    MemoryInstalled  = $systemInfos.MemoryInstalled
                    SystemDrive      = $systemInfos.SystemDrive
                    CPU              = $systemInfos.CPU -join '|'
                    BiosVersion      = $systemInfos.BIOSVersion
                })

            $null = $collection.Add($object)
        }
    }
    return $collection
}