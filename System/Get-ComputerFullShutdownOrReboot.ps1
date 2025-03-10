function Get-ComputerFullShutdownOrRebootEvents {
   
    $filterHashTable = @{
        LogName      = 'System'
        ProviderName = 'Microsoft-Windows-Kernel-Boot'
        ID           = 27
    }

    # Checking last full shutdown or reboot (ignore hibernation or FastStartup)
    <# eventID 27 message
    0x0: Full shutdown or reboot
    0x1: Shutdown with fast boot
    0x2: Resume from hibernation
    We want to check only for 0x0 because we want to know when the computer was completely shutdown or rebooted
    #>

    # Select the last boot. Event 27 is logged at boot time and contains info about the last shutdown/reboot
    $bootEvents = Get-WinEvent -FilterHashtable $filterHashTable -ErrorAction SilentlyContinue | Where-Object { $_.message -match '0x0' }

    if ($null -ne $bootEvents) {
        Write-Verbose 'Full shutdown or reboot event found'
    }
    else {
        Write-Verbose 'No boot event found (i.e no event log with ID 27, either because not exist or newer event logs overwritten older event 27 logs), use last reboot time from Win32_OperatingSystem'
        $bootEvents = (Get-CimInstance -ClassName Win32_OperatingSystem).LastBootUpTime
    }

    return $bootEvents
}