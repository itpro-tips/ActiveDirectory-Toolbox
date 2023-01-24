function Get-RemoteTimeDate {

    [CmdletBinding()]
    [OutputType([datetime])]
    param (
        $ComputerName
    )
    
    $remoteOSInfo = Get-WmiObject win32_OperatingSystem -ComputerName $ComputerName   
    [datetime]$remoteDateTime = $remoteOSInfo.convertToDatetime($remoteOSInfo.LocalDateTime)    
    return $remoteDateTime

}