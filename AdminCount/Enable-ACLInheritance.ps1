<# 
- example  for simulation:
$adminCount = . .\Find-ADObjectsWithStaleAdminSDHolder.ps1
    ### you can also use another script, more faster:
    . .\Get-ADObjectWithStaleAdminSDHolder.ps1
    $adminCount = Get-ADObjectWithStaleAdminSDHolder

foreach ($obj in $admincount){
    Enable-ACLInheritance -DistinguishedName $obj.DistinguishedName -Simulation
}

-example for real:
foreach ($obj in $admincount){
    Enable-ACLInheritance -DistinguishedName $obj.DistinguishedName
}
#>
function Enable-ACLInheritance {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$DistinguishedName,
        [Parameter(Mandatory = $false)]
        [switch]$Simulation
    )

    try {
        $currentObject = Get-ADObject -Identity $DistinguishedName -Properties adminCount
    }
    catch {
        Write-Warning "$DistinguishedName does not exist"
        return
    }
        
    if ($currentObject.adminCount) {
        if ($Simulation) {
            Write-Host -ForegroundColor Cyan "[SIMULATION] $DistinguishedName - Clear admincount attribute"
        }
        else {
            Write-Host -ForegroundColor Cyan "$DistinguishedName - Clear admincount attribute"
            try {
                Set-ADObject $DistinguishedName -Clear admincount
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }
    }
    else {
        if ($Simulation) {
            Write-Host -ForegroundColor Cyan "[SIMULATION] $DistinguishedName - Clear admincount attribute"
        }
        else {
            Write-Host -ForegroundColor Green "$DistinguishedName - admincount already cleared"
        }
    }

    $obj = "AD:$DistinguishedName"
    $acl = Get-ACL -Path $obj

    if ($Simulation) {
        Write-Host -ForegroundColor Cyan "[SIMULATION] $DistinguishedName - Enable inheritance"
    }
    else {
        if ($acl.AreAccessRulesProtected) {
            Write-Host -ForegroundColor Cyan "$DistinguishedName - Enable inheritance"
            $acl.SetAccessRuleProtection($false, $true)

            try {
                Set-Acl -Path $obj -AclObject $acl -ErrorAction Stop    
            }
            catch {
                Write-Warning $_.Exception.Message
            }
        }
        else {
            Write-Host -ForegroundColor Green "$DistinguishedName - Inheritance already enabled"
        }
    }
}