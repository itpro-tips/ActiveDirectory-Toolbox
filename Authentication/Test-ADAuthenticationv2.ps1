function Test-ADAuthentication {
	Param(
		[Parameter(Mandatory = $true)]
		[string]$User,
		[Parameter(Mandatory = $true)]
		$Password,
		[Parameter(Mandatory = $false)]
		$Server,
		[Parameter(Mandatory = $false)]
		[string]$Domain,
		[Parameter(Mandatory = $false)]
        [Switch]$Kerberos
	)
  
	Add-Type -AssemblyName System.DirectoryServices.AccountManagement
	
	$contextType = [System.DirectoryServices.AccountManagement.ContextType]::Domain
	
    [System.Collections.Generic.List[PSObject]]$arguments = @()

	$arguments.Add($contextType)
	$null = $arguments.Add($Domain)

	if($null -ne $Server){
		$arguments.Add($Server)
	}

    # Domain not specified, use the current one
    if([string]::IsNullOrWhitespace($Domain)){
        #  Kerberos - UserPrincipalName attribute used
        if($Kerberos) {
            if($user -notlike '*@*'){
               Write-Warning 'You need to use the UserPrincipalName to use Kerberos'
               return
            }
            else{
                # do not specify domain
                Write-Warning 'For now, this script does not support Kerberos against another domain. The connection attemp will be made against the current connected domain only'
            }
        }
        # NetBIOS\sAMAccountName used, NTLM
        else {
            $domain = $env:USERDOMAIN
        }
	}

	$principalContext = New-Object System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList $arguments -ErrorAction SilentlyContinue

	if ($null -eq $principalContext) {
		Write-Warning "$user - AD Authentication failed"
	}
	
	if ($principalContext.ValidateCredentials($User, $Password)) {
		Write-Host -ForegroundColor green "$User - AD Authentication OK"
	}
	else {
		Write-Warning "$Domain\$User - AD Authentication failed"
	}
}

#Test-ADAuthentication -User toto -Password passXX