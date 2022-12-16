#Gets all the SPNS in the domain
 
# Alternative way to get the same information using CMD.exe:
# dsquery * "DC=yourdomain,DC=com" -filter "(&(objectcategory=computer)(servicePrincipalName=*))" -attr distinguishedName servicePrincipalName > spns.txt

#$search = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
 
#$search.filter = "(servicePrincipalName=*)"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=person))"
#$search.filter = "(&(servicePrincipalName=*)(objectCategory=user))"
#$results = $search.Findall()

# or with setSPN :
# setspn -T medin -Q */*

function Get-ServicePrincipalNames {
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Computers')]
        [String]$ObjectType,
        [boolean[]]$GroupSPNByObject
    )

    if ($ObjectType -eq 'Users' ) {
        $filter = '(&(servicePrincipalName=*)(objectCategory=user))'
    }
    elseif ($ObjectType -eq 'Computers') {
        $filter = '(&(servicePrincipalName=*)(objectCategory=computer))'
    }
    else {
        $filter = '(servicePrincipalName=*)'
    }

    $objectsWithSPN = Get-ADObject -LDAPFilter $filter -Properties UserPrincipalName, ObjectCategory, SamAccountName, ServicePrincipalName, AdminCount, pwdLastSet, lastLogonTimestamp, Description

    [System.Collections.Generic.List[PSObject]]$SPNObjects = @()

    foreach ($objectWithSPN in $objectsWithSPN) {
        if ($GroupSPNByObject) {
            $object = [PSCustomObject][ordered]@{
                ServicePrincipalName = $objectWithSPN.ServicePrincipalName -join '|'
                Name                 = $objectWithSPN.Name
                SamAccountName       = $objectWithSPN.SamAccountName
                DistinguishedName    = $objectWithSPN.distinguishedName
                Description          = $objectWithSPN.Description
                ObjectCategory       = $objectWithSPN.ObjectClass
                LastLogonDate        = [datetime]::FromFileTime($objectWithSPN.lastLogonTimestamp)
                PasswordLastSet      = [datetime]::FromFileTime($objectWithSPN.pwdLastSet)
                AdminCount           = if ($objectWithSPN.adminCount -ne 1) { '-' }else { $objectWithSPN.admincount }
            }

            $SPNObjects.Add($object) 
        }
        else {
            foreach ($spn in $objectWithSPN.ServicePrincipalName) {
                $SPNComputerObject = $SPNComputerOS = $null
                $SPNComputerName = $spn.split('/')[1].split(':')[0]
                $SPNComputerExists = $false
            
                $SPNComputerObject = (Get-ADComputer -LDAPFilter "(|(dnsHostName=$SPNComputerName)(name=$SPNComputerName))" -Properties operatingSystem, lastLogonDate)

                if ($SPNComputerObject) {
                    $SPNComputerExists = $true

                }
                $object = [PSCustomObject][ordered]@{
                    ServicePrincipalName     = $spn
                    Name                     = $objectWithSPN.Name
                    SamAccountName           = $objectWithSPN.SamAccountName
                    DistinguishedName        = $objectWithSPN.distinguishedName
                    Description              = $objectWithSPN.Description
                    ObjectCategory           = $objectWithSPN.ObjectClass
                    LastLogonDate            = [datetime]::FromFileTime($objectWithSPN.lastLogonTimestamp)
                    AdminCount               = if ($objectWithSPN.adminCount -ne 1) { '-' }else { $objectWithSPN.admincount }
                    PasswordLastSet          = [datetime]::FromFileTime($objectWithSPN.pwdLastSet)
                    SPNService               = $spn.Split('/')[0]
                    SPNPort                  = $spn.Split(':')[1]
                    SPNComputer              = $SPNComputerName
                    SPNComputerExists        = $SPNComputerExists
                    SPNComputerOS            = $SPNComputerObject.operatingSystem
                    SPNComputerLastLogonDate = $SPNComputerObject.LastLogonDate
                }

                $SPNObjects.Add($object) 
            }
        }
    }

    return $SPNObjects
}