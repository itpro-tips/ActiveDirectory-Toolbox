function Get-SysvolReplicationProtocol {

    $DFSStateHash = @{
        '0' = 'Uninitialized'
        '1' = 'Initialized'
        '2' = 'Initial Sync'
        '3' = 'Auto Recovery'
        '4' = 'Normal'
        '5' = 'In Error'
    }
    
    $collection = New-Object System.Collections.ArrayList
    
    $computers = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
    
    $domainRoot = (Get-ADDomain).DistinguishedName
    
    try {
        $frs = (Get-ADObject -SearchBase "CN=Domain System Volume (SYSVOL share),CN=File Replication Service,CN=System,$domainRoot" -SearchScope OneLevel -Filter * ).count 
    }
    catch {
        $frs = 0
    }

    try {
        $dfs = (Get-ADObject -SearchBase "CN=Topology,CN=Domain System Volume,CN=DFSR-GlobalSettings,CN=System,$domainRoot" -Filter * -SearchScope OneLevel).count
    }
    catch {
        $dfs = 0
    }

    Write-Host -ForegroundColor Cyan "FRS objects: $frs"
    Write-Host -ForegroundColor Cyan "DFS objects: $dfs"
    
    foreach ($computer in $computers) {
        Write-Host "Processing $computer" -ForegroundColor Cyan
        $DFS = Get-WmiObject -Namespace "root\MicrosoftDFS" -Class DfsrReplicatedFolderInfo -ComputerName $computer | Where-Object { $_.ReplicatedFolderName -eq 'SYSVOL Share' } | Select-Object ReplicatedFolderName, ReplicationGroupName, State
    
    
        $dfsrservice = Get-Service dfsr -ComputerName $computer
    
        $object = New-Object -TypeName PSObject -Property ([ordered]@{
                ComputerName     = $computer.ToUpper()
                DFSState         = $DFSStateHash[$DFS.State.ToString()]
                DFSRServiceState = $dfsrservice.Status
            })
    
        $null = $collection.Add($object)
    }
    
    return $collection    
}