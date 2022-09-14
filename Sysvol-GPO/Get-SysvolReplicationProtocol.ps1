function Get-SysvolReplicationProtocol {

    $DFSStateHash = @{
        '0' = 'Uninitialized'
        '1' = 'Initialized'
        '2' = 'Initial Sync'
        '3' = 'Auto Recovery'
        '4' = 'Normal'
        '5' = 'In Error'
    }
    
    [System.Collections.Generic.List[PSObject]]$sysvolReplicationProtocolArray = @()
    
    $computers = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
    
    $domainRoot = (Get-ADDomain).DistinguishedName
    
    try {
        # cast in array in case of only one DC
        $frsObjects = @((Get-ADObject -SearchBase "CN=Domain System Volume (SYSVOL share),CN=File Replication Service,CN=System,$domainRoot" -SearchScope OneLevel -Filter *)).count 
    }
    catch {
        $frsObjects = 0
    }

    try {
        # cast in array in case of only one DC
        $dfsObjects = @((Get-ADObject -SearchBase "CN=Topology,CN=Domain System Volume,CN=DFSR-GlobalSettings,CN=System,$domainRoot" -SearchScope OneLevel -Filter *)).count
    }
    catch {
        $dfsObjects = 0
    }
    
    Write-Host -ForegroundColor Cyan "FRS objects: $frsObjects"
    Write-Host -ForegroundColor Cyan "DFS objects: $dfsObjects"
    
    foreach ($computer in $computers) {
        Write-Host "Processing $computer" -ForegroundColor Cyan
        if ($dfsObjects -ne 0) {
            $DFS = Get-WmiObject -Namespace "root\MicrosoftDFS" -Class DfsrReplicatedFolderInfo -ComputerName $computer | Where-Object { $_.ReplicatedFolderName -eq 'SYSVOL Share' } | Select-Object ReplicatedFolderName, ReplicationGroupName, State
        }
        
        $dfsrService = Get-Service dfsr -ComputerName $computer
        $ntfrsService = Get-Service ntfrs -ComputerName $computer

        $object = [PSCustomObject][ordered]@{
                ComputerName         = $computer.ToUpper()
                DFSState             = if ($DFS) { $DFSStateHash[$DFS.State.ToString()] } else { 'NotEnabled' }
                DFSRServiceState     = $dfsrService.Status
                DFSRServiceStartType = $dfsrService.StartType
                NTFRSState           = $ntfrsService.Status
                NTFRSStartType       = $ntfrsService.StartType  
            }
    
        $sysvolReplicationProtocolArray.Add($object)
    }
    
    return $sysvolReplicationProtocolArray    
}