function Get-TCPUDPByProcess {

    Param(
        [CmdletBinding()]
        [Parameter (Mandatory = $false)]
        [String]$ComputerName,
        [Parameter (Mandatory = $false)]
        [String]$ProcessName,
        [Parameter (Mandatory = $false)]
        [String]$LocalPort,
        [Parameter (Mandatory = $false)]
        [Switch]$TCPOnly,
        [Parameter (Mandatory = $false)]
        [Switch]$UDPOnly
    )

    function Get-TCPUDP {
        Param(
            [Boolean]$TCPOnly,
            [Parameter (Mandatory = $false)]
            [Boolean]$UDPOnly
        )

        [System.Collections.Generic.List[PSObject]]$portsArray = @()

        $services = @{}
        
        # Build a hashtable of services by PID
        Get-WmiObject win32_service | ForEach-Object {
            # if ProcessID already exists, append ServiceName to the existing value
            if ($services[[int]$_.ProcessId]) {
                $services[[int]$_.ProcessId] = $services[[int]$_.ProcessId] + '|' + $_.Name
            }
            else {   
                $services[[int]$_.ProcessId] = $_.Name
            }
        }

        $processes = @{}
    
        if ((New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            # Elevated - get account info per process
            Get-Process -IncludeUserName | ForEach-Object {
                $processes[$_.Id] = $_
            }
        }
        else {
            # Not Elevated - don't collect per-process account info
            Get-Process  | ForEach-Object {
                $processes[[int]$_.Id] = $_
            }
        }
     
        if ((-not $UDPOnly) -or $TCPOnly) {
            # Query Listening TCP Ports and Connections
            $TCPPorts = Get-NetTCPConnection | Select-Object LocalAddress, RemoteAddress,
            @{Name = 'Protocol'; Expression = { 'TCP' } },
            LocalPort, RemotePort, State,
            @{Name = 'PID'; Expression = { $_.OwningProcess } },
            @{Name = 'UserName'; Expression = { $processes[[int]$_.OwningProcess].UserName } },
            @{Name = 'ProcessName'; Expression = { $processes[[int]$_.OwningProcess].ProcessName } },
            @{Name = 'Path'; Expression = { $processes[[int]$_.OwningProcess].Path } },
            @{Name = 'ServiceName'; Expression = { $services[[int]$_.OwningProcess] } }

            $TCPPorts | ForEach-Object {
                $portsArray.Add($_)
            }
        }
        
        if ((-not $TCPOnly) -or $UDPOnly) {
            # Query Listening UDP Ports (No Connections in UDP)
            $UDPPorts = Get-NetUDPEndpoint | Select-Object LocalAddress, RemoteAddress,
            @{Name = 'Protocol'; Expression = { 'UDP' } },
            LocalPort, RemotePort, State,
            @{Name = 'PID'; Expression = { $_.OwningProcess } },
            @{Name = 'UserName'; Expression = { $processes[[int]$_.OwningProcess].UserName } },
            @{Name = 'ProcessName'; Expression = { $processes[[int]$_.OwningProcess].ProcessName } },
            @{Name = 'Path'; Expression = { $processes[[int]$_.OwningProcess].Path } },
            @{Name = 'ServiceName'; Expression = { $services[[int]$_.OwningProcess] } } 

            foreach ($UDPPort in $UDPPorts) {
                if ($UDPPort.LocalAddress -eq '0.0.0.0' -or $UDPPort.LocalAddress -eq '::1') {
                    $UDPPort.State = 'UDP listen'
                } 
            }

            $UDPPorts | ForEach-Object {
                $portsArray.Add($_)
            }
        }
        return $portsArray
    }

    $argumentList = @{}
    if ($TCPOnly) {
        $argumentList.Add('TCPOnly', $true)
    }

    elseif ($UDPOnly) {
        $argumentList.Add('UDPOnly', $true)
    }
    # Remote Computer
    if ($null -ne $ComputerName -or $ComputerName -eq $env:COMPUTERNAME -or $ComputerName -eq 'localhost') {
        $TCPUDP = Get-TCPUDP @argumentList
    }
    else {
        $TCPUDP = Invoke-Command -ComputerName $ComputerName ${function:Get-TCPUDP} -ArgumentList $argumentList
    }

    
    if (-not [string]::IsNullOrWhitespace($ProcessName)) {
        $TCPUDP = $TCPUDP | Where-Object { $_.ProcessName -eq $ProcessName }
    }

    if (-not [string]::IsNullOrWhitespace($LocalPort)) {
        $TCPUDP = $TCPUDP | Where-Object { $_.LocalPort -eq $LocalPort }
    }

    return $TCPUDP
}