function Get-ADObjectUserCertificate {
    # Parameter help description
    [String]$Domain

    [System.Collections.Generic.List[PSObject]]$certificatesArray = @()

    if ($domain) {
        $adObjectsWithCertificate = Get-ADObject -Filter { UserCertificate -like '*' -or userCert -like '*' -or UserSMIMECertificate -like '*' } -Properties * -Server $Domain    
    }
    else {
        $adObjectsWithCertificate = Get-ADObject -Filter { UserCertificate -like '*' -or userCert -like '*' -or UserSMIMECertificate -like '*' } -Properties *
    }

    foreach ($adObject in $ADObjectsWithCertificate) {
        $certs = @()

        if ($adObject.UserCertificate) {
            $adObject | Select-Object -ExpandProperty usercertificate | ForEach-Object {
                $certs = + [System.Security.Cryptography.X509Certificates.X509Certificate2]$_
            }
        }
        if ($adObject.UserSMIMECertificate) {
            $adObject | Select-Object -ExpandProperty UserSMIMECertificate | ForEach-Object {
                $certs = + [System.Security.Cryptography.X509Certificates.X509Certificate2]$_
            }
        }
        if ($adObject.userCert) {
            $adObject | Select-Object -ExpandProperty UserSMIMECertificate | ForEach-Object {
                $certs = + [System.Security.Cryptography.X509Certificates.X509Certificate2]$_
            }
        }

        foreach ($cert in $certs) {
            $object = [PSCustomObject][ordered]@{
                Name               = $adObject.Name
                DisplayName        = $adObject.displayname
                DN                 = $adObject.DistinguishedName
                IssuedTo           = $cert.Subject
                IssuedBy           = $cert.Issuer
                IntendedPurpose    = $cert.EnhancedKeyUsageList
                NotBefore          = $cert.NotBefore
                NotAfter           = $cert.NotAfter
                SerialNumber       = $cert.SerialNumber
                Thumbprint         = $cert.Thumbprint
                ObjectClass        = $adObject.ObjectClass
                CertDnsNameList    = $cert.DnsNameList
                IssuerName         = $cert.IssuerName.Name
                SubjectName        = $cert.SubjectName.Name
                SignatureAlgorithm = $cert.SignatureAlgorithm.FriendlyName
            }

            $certificatesArray.Add($object)
        }
    }
}