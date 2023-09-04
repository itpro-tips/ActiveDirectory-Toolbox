<#
AdminSDProtectFrequency (DWORD) dans HKLM\SYSTEM\CurrentControlSet\Services\NTDS\Parameters

Get this value in the registry and convert it to a readable format:
#>
# if null, it is because the value is not set and the default is 3600 seconds

# test if the current computer is the PDC
$PDC = (Get-ADDomainController -Filter {OperationMasterRoles -like "*PDCEmulator*" }).Name
$CurrentComputer = $env:COMPUTERNAME

if ($PDC -ne $CurrentComputer) {
    Write-Warning "This computer is not the PDC. Please run this script on the PDC"
    return
}

try {
    $AdminSDProtectFrequency = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\NTDS\Parameters' -Name AdminSDProtectFrequency -ErrorAction Stop).AdminSDProtectFrequency
}
catch {
    $AdminSDProtectFrequency = 3600
}

return $AdminSDProtectFrequency