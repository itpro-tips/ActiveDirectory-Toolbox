# Assessment scanner for CVE-2020-1472
# See https://support.microsoft.com/en-us/help/4557222/how-to-manage-the-changes-in-netlogon-secure-channel-connections-assoc
# Note hotfix list will become out of date quickly
# Loosely based on CISA validation script: https://github.com/cisagov/cyber.dhs.gov/tree/master/assets/report/ed-20-04_script
# technion@lolware.net

Set-StrictMode -Version 2

# Obtain all Domain Controllers in Forest
$allDCs = $((Get-ADForest).Domains | ForEach-Object { Get-ADDomainController -Filter * -Server $_ })


# Final array of reviewed domain controllers
[System.Collections.ArrayList]$validatedList = @()

# Currently available cumulative updates containing patches
$hotfixList = @("KB4571729", "KB4571719", "KB4571736", "KB4571702", "KB4571703", "KB4571723", "KB4571694", "KB4565349", "KB4565351", "KB4566782", "KB4577051", "KB4577038", "KB4577066", `
 "KB4577015","KB4577069", "KB4574727", "KB4577062", "KB4571744", "KB4571756", "KB4571748", "KB4570333", "KB4577069")

$allDCs | ForEach-Object {

    $DC = $_.Hostname
    $OS = $(Get-WmiObject -ComputerName $DC -Class Win32_OperatingSystem).caption

    Write-Host "Evaluating Domain Controller: $DC"

    # Build an object defaulting to "unpatched"
    $DCObj = New-Object -TypeName psobject
    $DCObj | Add-Member -MemberType NoteProperty -Name "DomainController" -Value $DC
    $DCObj | Add-Member -MemberType NoteProperty -Name "OperatingSystem" -Value $OS
    $DCObj | Add-Member -MemberType NoteProperty -Name "Update" -Value "No KB has been installed"
    $DCObj | Add-Member -MemberType NoteProperty -Name "Compliance" -Value $False
    $DCObj | Add-Member -MemberType NoteProperty -Name "Enforcement" -Value $False

    $hotfixes = Get-WmiObject Win32_quickfixengineering -ComputerName $DC | Select-Object hotfixId
    $foundFix = $hotfixes.hotfixId | where-object {$hotfixList -contains $_}
    if ($foundFix) {
        $DCObj.Update = $foundfix -join ' '
        $DCObj.Compliance = $true
    }

    # Invoke-Command will fail on localhost
    if ([System.Net.Dns]::GetHostByName(($env:computerName)).HostName -eq $DC) {
        $enforced = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Name FullSecureChannelProtection -ErrorAction SilentlyContinue
    } else {
        $enforced = Invoke-Command -ComputerName $DC  {
            Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon\Parameters' -Name FullSecureChannelProtection -ErrorAction SilentlyContinue
        }
    }

    if ($enforced -and $enforced.FullSecureChannelProtection -eq 1) { 
        $DCObj.Enforcement = $true
    }

    $validatedList.Add($DCObj) | Out-Null
}

$validatedList | ft