# Based on Russell Tomkins' script
# source : https://github.com/russelltomkins/Active-Directory/blob/master/Query-insecureLDAPBinds.ps1
# https://docs.microsoft.com/en-us/archive/blogs/russellt/identifying-clear-text-ldap-binds-to-your-dcs
#requires -Version 5

function Get-InsecureLDAPBinds {
    [CmdletBinding()]
    Param (
        [parameter(Mandatory = $false, Position = 0)]
        $DomainControllers = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers.Name,
        [parameter(Mandatory = $false, Position = 1)]
        [DateTime]$BeginDate = $((Get-Date).AddDays(-5)),
        [parameter(Mandatory = $false, Position = 2)]
        [DateTime]$EndDate = "$(Get-Date)",
        [parameter(Mandatory = $false)]
        [boolean]$ExportResults = $false,
        [boolean]$CompareAdminCount
    )

    # ArraysList faster than array @()
    [System.Collections.Generic.List[PSObject]]$insecureLDAPBinds = @()

    if ($CompareAdminCount) {
        $adminCountObjects = (Get-ADObject -Filter { adminCount -like '1' } -Properties SamaccountName).SamaccountName
    }

    $DNSNameResolved = @{ }

    $filter = @{
        LogName   = 'Directory Service'
        ID        = 2889
        StartTime = $BeginDate
        EndTime   = $EndDate
    } 

    foreach ($DC in $DomainControllers) {
        $events = $null
        Write-Host -ForegroundColor cyan "Get eventID $($filter.ID) from $DC... " -NoNewline
        # if DC is the local machine, use Get-WinEvent, else use Invoke-Command
        if($DC -eq "$($env:COMPUTERNAME).$($env:USERDNSDOMAIN)") {
            Write-Host -ForegroundColor Cyan 'Local machine'
            try {
                $events = Get-WinEvent -FilterHashtable $filter -ErrorAction SilentlyContinue
            }
            catch {
                Write-Warning "$($_.Exception.Message)"
            }
        }
        else {
            $events = Invoke-Command -ComputerName $DC -ScriptBlock {
                try {
                    Get-WinEvent -FilterHashtable $args[0] -ErrorAction Stop
                }
                catch {
                    Write-Warning "$($_.Exception.Message)"
                }
            } -ArgumentList $filter
        }
        # Grab the appropriate event entries
        try {
            # With Invoke-Command, it seems we loose the .toXML method for events. Maybe it's better to use Get-WinEvent -FilterHashtable $filter -ComputerName
            # cast to array to get $events.count even if there is only one event
            [array]$events = Invoke-Command -ComputerName $DC -ScriptBlock {
                try {
                    Get-WinEvent -FilterHashtable $args[0] -ErrorAction Stop
                }
                catch {
                    Write-Warning "$($_.Exception.Message)"
                }
            } -ArgumentList $filter
            #$events = Get-WinEvent -ComputerName $DC -FilterHashtable $filter -ErrorAction Stop
        }
        catch {
            if ($_.FullyQualifiedErrorID -match 'NoMatchingEventsFound,Microsoft.PowerShell.Commands.GetWinEventCommand') {
                Write-Host -ForegroundColor Green "No events were found."
            }
            else {
                Write-Warning "$_"
            }

            continue
        }

        Write-Host -ForegroundColor Yellow "$($events.count) events were found."
        # Loop through each event and output the 
        foreach ($event in $events) { 
            <#
        $eventXML = [xml]$event.ToXml()
	
        # Build Our Values

        $Client = ($eventXML.event.eventData.Data[0])
        $IPAddress = $Client.SubString(0, $Client.LastIndexOf(":")) #Accomodates for IPV6 Addresses
        $Port = $Client.SubString($Client.LastIndexOf(":") + 1) #Accomodates for IPV6 Addresses
        $User = $eventXML.event.eventData.Data[1]
        $RecordId = $event.RecordId
        $date = $event.TimeCreated
        Switch ($eventXML.event.eventData.Data[2]) {
            0 { $BindType = "Unsigned" }
            1 { $BindType = "Simple" }
        }
        #>
	
            Switch (($event.Message -split "`r`n")[7]) {
                0 {
                    $bindType = 'Unsigned'
                    break
                }
                1 {
                    $bindType = 'Simple'
                    break
                }
            }
        
            $IPAddress = ($event.Message -split "`r`n")[3].Substring(0, ($event.Message -split "`r`n")[3].LastIndexOf(':'))
        
            # Attempt to resolve DNSName and used hashtable to store previsously resolved IP to speed up
            if (-not($DNSNameResolved.ContainsKey($IPAddress))) {
                $dnsName = (Resolve-DnsName $IPAddress -DnsOnly -ErrorAction SilentlyContinue).NameHost

                if ($null -eq $dnsName) {
                    $DNSNameResolved.Add($IPAddress, 'Unknown')
                }
                else {
                    #Sometimes, an entry can match several DNS names
                    $IPAddress = $IPAddress -join '|'
                    $dnsName = $dnsName -join '|'

                    $DNSNameResolved.Add($IPAddress , $dnsName)
                }
            }
        
            $DNSName = $DNSNameResolved[$IPAddress]

            $object = [PSCustomObject][ordered] @{
                Date             = $event.TimeCreated
                DomainController = $DC
                ClientIP         = $IPAddress
                ClientDNSName    = $dnsName
                Port             = ($event.Message -split "`r`n")[3].Substring(($event.Message -split "`r`n")[3].LastIndexOf(':') + 1 ).Trim()
                User             = ($event.Message -split "`r`n")[5].Trim()
                BindType         = $bindType
            }

            if ($CompareAdminCount) {
                if ($adminCountObjects -contains $object.User.Split('\')[1]) {
                    $object | Add-Member -MemberType NoteProperty -Name 'IsAdminCount' -Value $true
                }
                else {
                    $object | Add-Member -MemberType NoteProperty -Name 'IsAdminCount' -Value $false
                }
            }

            # Add the row to our Array
            $insecureLDAPBinds.Add($object)
        }
    }

    if ($ExportResults) {
        $export = "$($env:USERPROFILE)\$(Get-Date -Format yyyyMMdd_HHmm)_InsecureLDAP_detailled.csv"
        Write-Host "Export detailled result to $export"
        $insecureLDAPBinds | Export-Csv $export -NoTypeInformation -Encoding UTF8

        $exportSummary = "$($env:USERPROFILE)\$(Get-Date -Format yyyyMMdd_HHmm)_InsecureLDAP_summary.csv"
        $insecureLDAPBinds | Group-Object ClientIP, ClientDNSName, User, DomainController  | Select-Object count, Name | Sort-Object count -Descending | Export-Csv $exportSummary -NoTypeInformation -Encoding UTF8

        #Invoke-Item $env:USERPROFILE
    }
    else {
        $insecureLDAPBinds
    }
}