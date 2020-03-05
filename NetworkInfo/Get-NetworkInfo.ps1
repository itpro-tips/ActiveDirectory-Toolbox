#Requires -Version 3.0

Function Get-NetworkInfo {
    Param
    (
        [string[]]$ComputerName = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
    )

    $collection = New-Object System.Collections.ArrayList

    foreach ($computer in $ComputerName) {

        $networks = $null

        try {
            $networks = Get-WmiObject Win32_NetworkAdapterConfiguration -ComputerName $computer -ErrorAction Stop | Where-Object { $_.IPEnabled }
        }
        catch {
            Write-Warning $_.Exception.Message
        }

        if ($networks) {
            foreach ($network in $networks) {
                $isDHCPEnabled = $false
                
                If ($network.DHCPEnabled) {
                    $isDHCPEnabled = $true
                }

                $obj = New-Object -TypeName PSObject -Property ([ordered]@{
                        ComputerName        = $Computer.ToUpper()
                        NetworkCard         = $network.Description
                        IPAddress           = $network.IpAddress[0]
                        SubnetMask          = $network.IPSubnet[0]
                        Gateway             = $network.DefaultIPGateway -join '|'
                        IsDHCPEnabled       = $isDHCPEnabled
                        DNSServersSearch    = $network.DNSServerSearchOrder -join '|'
                        WINSPrimaryserver   = $networks.WINSPrimaryServer
                        WINSSecondaryserver = $networks.WINSSecondaryserver
                    })
                $null = $collection.Add($obj)
            }
        }
          
        return $collection
    }
}