function Get-ADObjectUserCertificate {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String]$DistinguishedName,
        [Parameter(Mandatory = $false)]
        [String]$DomainController
    )    
    
    [System.Collections.Generic.List[PSObject]]$certificatesArray = @()

    if (-not ($DomainController)) {
        $DomainController = $env:USERDNSDOMAIN
    }    

    if ($DistinguishedName) {
        $adObjectsWithCertificate = Get-ADObject -Identity $DistinguishedName -Properties * -Server $DomainController
    }
    else {
        $adObjectsWithCertificate = Get-ADObject -Filter { UserCertificate -like '*' -or userCert -like '*' -or UserSMIMECertificate -like '*' } -Properties *  -Server $DomainController
    }

    foreach ($adObject in $ADObjectsWithCertificate) {
        [System.Collections.Generic.List[PSObject]]$certificates = @()

        if ($adObject.UserCertificate) {
            $adObject | Select-Object -ExpandProperty usercertificate | ForEach-Object {
                $certificates.Add([System.Security.Cryptography.X509Certificates.X509Certificate2]$_)
            }
        }
        if ($adObject.UserSMIMECertificate) {
            $adObject | Select-Object -ExpandProperty UserSMIMECertificate | ForEach-Object {
                $certificates.Add([System.Security.Cryptography.X509Certificates.X509Certificate2]$_)
            }
        }
        if ($adObject.userCert) {
            $adObject | Select-Object -ExpandProperty UserSMIMECertificate | ForEach-Object {
                $certificates.Add([System.Security.Cryptography.X509Certificates.X509Certificate2]$_)
            }
        }

        foreach ($certificate in $certificates) {
            $object = [PSCustomObject][ordered]@{
                Name               = $adObject.Name
                DisplayName        = $adObject.displayname
                DN                 = $adObject.DistinguishedName
                IssuedTo           = $certificate.Subject
                IssuedBy           = $certificate.Issuer
                IntendedPurpose    = $certificate.EnhancedKeyUsageList
                NotBefore          = $certificate.NotBefore
                NotAfter           = $certificate.NotAfter
                SerialNumber       = $certificate.SerialNumber
                Thumbprint         = $certificate.Thumbprint
                ObjectClass        = $adObject.ObjectClass
                CertDnsNameList    = $certificate.DnsNameList
                IssuerName         = $certificate.IssuerName.Name
                SubjectName        = $certificate.SubjectName.Name
                SignatureAlgorithm = $certificate.SignatureAlgorithm.FriendlyName
            }

            $certificatesArray.Add($object)
        }
    }

    return $certificatesArray
}