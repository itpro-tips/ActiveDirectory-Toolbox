<# example  :
$adminCount = . .\Find-ADObjectsWithStaleAdminSDHolder.ps1

foreach ($obj in $admincount){
    Enable-ACLInheritance -DistinguishedName $obj.DistinguishedName -Simulation $false
}
#>
Function Enable-ACLInheritance {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]$DistinguishedName,
        [Parameter(Mandatory = $false)]
        [Boolean]$Simulation
    )

    try {
        $currentObject = Get-ADObject -Identity $DistinguishedName -Properties adminCount
    }
    catch {
        Write-Warning "$DistinguishedName does not exist"
        return
    }

    $obj = "AD:$DistinguishedName"
    $acl = Get-ACL -Path $obj

    if ($Simulation) {
        Write-Host -ForegroundColor Cyan "[SIMULATION] $DistinguishedName - Enable inheritance"
    }
    else {
        if ($acl.AreAccessRulesProtected) {
            Write-Host -ForegroundColor Cyan "$DistinguishedName - Enable inheritance"
            <# https://learn.microsoft.com/en-us/dotnet/api/system.security.accesscontrol.objectsecurity.setaccessruleprotection?view=net-7.0
            AreAccessRulesProtected(bool isProtected, bool preserveInheritance);
            - isProtected:
                true to protect the access rules associated with this ObjectSecurity object from inheritance
                false to allow inheritance
            - preserveInheritance
            true to preserve inherited access rules
            false to remove inherited access rules. This parameter is ignored if isProtected is false.
            #>
            
            $acl.SetAccessRuleProtection($False, $True)
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
}