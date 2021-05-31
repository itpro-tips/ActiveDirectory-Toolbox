function Get-TCPUDPByProcess {

    Param(
        [Parameter(Mandatory)]
        $ComputerName
    )

    function RemoteTCPUDPByProcess {
        $portsArray = New-Object System.Collections.ArrayList
        
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
                $processes[$_.Id] = $_
            }
        }
     
        # Query Listening TCP Ports and Connections
        $TCPPorts = Get-NetTCPConnection |
        Select-Object LocalAddress,
        RemoteAddress,
        @{Name = 'Protocol'; Expression = { 'TCP' } },
        LocalPort, RemotePort, State,
        @{Name = 'PID'; Expression = { $_.OwningProcess } },
        @{Name = 'UserName'; Expression = { $processes[[int]$_.OwningProcess].UserName } },
        @{Name = 'ProcessName'; Expression = { $processes[[int]$_.OwningProcess].ProcessName } },
        @{Name = 'Path'; Expression = { $processes[[int]$_.OwningProcess].Path } } |
        Sort-Object -Property LocalPort, UserName
    
        $TCPPorts | ForEach-Object { $null = $portsArray.Add($_) }

        # Query Listening UDP Ports (No Connections in UDP)
        $UDPPorts = Get-NetUDPEndpoint |
        Select-Object LocalAddress, RemoteAddress,
        @{Name = 'Protocol'; Expression = { 'UDP' } },
        LocalPort, RemotePort, State,
        @{Name = 'PID'; Expression = { $_.OwningProcess } },
        @{Name = 'UserName'; Expression = { $processes[[int]$_.OwningProcess].UserName } },
        @{Name = 'ProcessName'; Expression = { $processes[[int]$_.OwningProcess].ProcessName } },
        @{Name = 'Path'; Expression = { $processes[[int]$_.OwningProcess].Path } } |
        Sort-Object -Property LocalPort, UserName
        foreach ($UDPPort in $UDPPorts) {
            if ( $UDPPort.LocalAddress -eq '0.0.0.0') { $UDPPort.State = 'Listen' } 
        }

        $UDPPorts | ForEach-Object { $null = $portsArray.Add($_) }

        return $portsArray
    }

    $TCPUDP = Invoke-Command -ComputerName $ComputerName ${function:RemoteTCPUDPByProcess}

    return $TCPUDP
}