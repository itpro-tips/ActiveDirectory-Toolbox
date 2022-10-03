function Get-ComputerHostsFile {
    <#
    .SYNOPSIS
    Parses a hosts file and return IP, Hostname, Comment and Line
    
    Inspired by : Matthew Graeber (@mattifestation)
    
    .PARAMETER HostsFilePath
    Specifies an alternate HOSTS path. Defaults to
    "$env:SystemRoot\System32\Drivers\etc\hosts"
    
    .PARAMETER ComputerName
    Remote computer (use WSMan)

    .EXAMPLE
    Get-ComputerHostsFile
    
    .EXAMPLE
    Get-ComputerHostsFile -ComputerName DC01 -HostsFilePath D:\Windows\System32\drivers\etc\hosts

    #>
    
    Param (
        [String]$HostsFilePath,
        [String]$ComputerName
    )
    
    [System.Collections.Generic.List[PSObject]]$hostsArray = @()

    if (-not $HostsFilePath) {
        $HostsFilePath = "$env:SystemRoot\System32\Drivers\etc\hosts"
    }

    if ($ComputerName) {
        $hostsFileContent = Invoke-Command -ComputerName $ComputerName { Get-Content $args[0] } -ArgumentList $HostsFilePath
    }
    else {
        $hostsFileContent = Get-Content $HostsFilePath -ErrorAction Stop
    }

    $lineNumber = 0

    foreach ($line in $hostsFileContent) {
        $lineNum++
        $commentLine = '^\s*#'
        $hostLine = '^\s*(?<IPAddress>\S+)\s+(?<Hostname>\S+)(\s*|\s+#(?<Comment>.*))$'
    
        $testIP = [Net.IPAddress] '127.0.0.1'

        if (-not  ($line -match $CommentLine) -and ($line -match $HostLine)) {
            $ipAddress = $Matches['IPAddress']
            $comment = ''
    
            if ($Matches['Comment']) {
                $comment = $Matches['Comment']
            }
    
            $object = [PSCustomObject][ordered] @{
                IPAddress  = $IpAddress
                Hostname   = $Matches['Hostname']
                IsValidIP  = [Net.IPAddress]::TryParse($ipAddress, [Ref] $TestIP)
                Comment    = $comment.Trim(' ')
                LineNumber = $lineNumber
            }
    
            $hostsArray.Add($object) 
        }
    }

    return $hostsArray
}