Function Invoke-ADSDPropagation{
    <#
    .SYNOPSIS
        Invoke a SDProp task on the PDCe.
    .DESCRIPTION
        Make an LDAP call to trigger SDProp.
    .EXAMPLE
        Invoke-ADSDPropagation
        By default, RunProtectAdminGroupsTask is used for Windows Server 2008R2 and later.
    .EXAMPLE
        Invoke-ADSDPropagation -TaskName FixUpInheritance
        Use the legacy FixUpInheritance task name for Windows Server 2003 and earlier.
    .PARAMETER TaskName
        Name of the task to use.
            - FixUpInheritance for legacy OS (2008 or earlier)
            - RunProtectAdminGroupsTask for recent OS (from 2008 R2)
    .INPUTS
    .OUTPUTS
    .NOTES
        You can track progress with:
        Get-Counter -Counter '\directoryservices(ntds)\ds security descriptor propagator runtime queue' | Select-Object -ExpandProperty CounterSamples | Select-Object -ExpandProperty CookedValue
    .LINK
        http://ItForDummies.net
    #>
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$false,
            HelpMessage='Name of the domain where to force SDProp to run',
            Position=0)]
        [ValidateScript({Test-Connection -ComputerName $_ -Count 2 -Quiet})]
        [String]$DomainName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().Name,

        [ValidateSet('RunProtectAdminGroupsTask','FixUpInheritance')]
        [String]$TaskName = 'RunProtectAdminGroupsTask'
    )

    try{
	$DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext('domain',$DomainName)
        $DomainObject = [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
        
        Write-Verbose -Message "Detected PDCe is $($DomainObject.PdcRoleOwner.Name)."
        $RootDSE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://$($DomainObject.PdcRoleOwner.Name)/RootDSE") 
        $RootDSE.UsePropertyCache = $false 
        $RootDSE.Put($TaskName, "1") # RunProtectAdminGroupsTask & fixupinheritance
        $RootDSE.SetInfo()
    }
    catch{
        throw "Can't invoke SDProp on $($DomainObject.PdcRoleOwner.Name) !"
    }
}
