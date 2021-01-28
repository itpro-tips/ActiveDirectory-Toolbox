#requires -Version 3
function Invoke-BestPracticeAnalyzer {
    Param(
        # Parameter help description
        [Parameter(Mandatory)]
        [string[]]$Computers,
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
        # the data consolidation can take time, so we launch the BPA first then we take info.
        foreach ($BPAService in $BPAServices) {
            Write-Host "$computer Invoke Best Practice Analyser $BPAService" -ForegroundColor cyan
            #$null = Invoke-BpaModel -ModelId $BPAService -ComputerName $computer
            # Used Invoke-Command in order to keep results files remotely
            $null = Invoke-Command -ComputerName $computer -ScriptBlock { Invoke-BpaModel -ModelId $args[0] -WarningAction SilentlyContinue } -ArgumentList $BPAService
        }

        foreach ($BPAService in $BPAServices) {
            Write-Host "$computer Get Best Practice Analyser results $BPAService" -ForegroundColor cyan
            $results = Invoke-Command -ComputerName $computer -ScriptBlock { Get-BpaResult -ModelId $args[0] -ErrorAction SilentlyContinue } -ArgumentList $BPAService

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
}