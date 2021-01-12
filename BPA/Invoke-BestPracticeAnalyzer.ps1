#requires -Version 3

Param(
    [string[]]$Computers = 'localhost',
    [switch]$DomainControllers)

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run PowerShell as administrator"
    exit
}

try {
    Import-Module BestPractices -ErrorAction stop
}
catch {
    Write-Warning "$($_.Exception.Message)"
    exit 1
}

if ($domainControllers) {
    $computers = ([System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().DomainControllers).Name
}

$BPAServices = @(
    'Microsoft/Windows/CertificateServices',
    'Microsoft/Windows/DHCPServer',
    'Microsoft/Windows/DirectoryServices',  
    'Microsoft/Windows/DNSServer'
)

$BPAResults = New-Object System.Collections.ArrayList

foreach ($computer in $computers) {

    foreach ($BPAService in $BPAServices) {
        Write-Host "Processing $computer Best Practice Analyser $BPAService" -ForegroundColor cyan
        #$null = Invoke-BpaModel -ModelId $BPAService -ComputerName $computer

        $null = Invoke-Command -ComputerName $computer -ScriptBlock { Invoke-BpaModel -ModelId $using:BPAService } 

        $results = Invoke-Command -ComputerName $computer -ScriptBlock { Get-BpaResult -ModelId $using:BPAService } 

        foreach ($result in $results) {
            $object = [PSCustomObject][ordered]@{
                Category        = $result.Category
                Compliance      = $result.Compliance
                ComputerName    = $result.ComputerName
                Context         = $result.Context
                Excluded        = $result.Excluded
                Help            = $result.Help
                Impact          = $result.Impact
                ModelId         = $result.ModelId
                NeutralCategory = $result.NeutralCategory
                NeutralSeverity = $result.NeutralSeverity
                Problem         = $result.Problem
                Resolution      = $result.Resolution
                ResultId        = $result.ResultId
                ResultNumber    = $result.ResultNumber
                RuleId          = $result.RuleId
                Severity        = $result.Severity
                Source          = $result.Source
                SubModelId      = $result.SubModelId
                Title           = $result.Title
            }

            $null = $BPAResults.Add($object)
        }
    }
}

return $BPAResults