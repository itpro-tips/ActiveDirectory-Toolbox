function Get-RemoteLocalGroupsMembership {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [String[]]$ComputerName
    )

    [System.Collections.Generic.List[PSObject]]$remoteLocalGroupsMembershipArray = @()

    foreach ($computer in $ComputerName) {

        if ($computer -eq 'localhost') {
            $computer = $env:COMPUTERNAME
        }
        
        $adsi = [ADSI]"WinNT://$computer,computer"

        try {
            # Test ADSI
            [void]$adsi.Tostring()
        }
        catch {
            # Try with invoke-command if not the local computer and load the function because sometimes the network path is not found
            if ($env:COMPUTERNAME -ne $computer) {
            
                $adsi = Invoke-Command -ComputerName $computer -ScriptBlock {
                    [ADSI]"WinNT://$env:COMPUTERNAME,computer"
                }
            }

            try {
                [void]$adsi.Tostring()
            }
            catch {
                $errorMessage = $_.Exception.Message

                $object = [PSCustomObject][ordered]@{
                    Computername          = $Computer
                    GroupName             = $errorMessage
                    GroupDescription      = $errorMessage
                    MemberName            = $errorMessage
                    MemberType            = $errorMessage
                    MemberPath            = $errorMessage
                    MemberPrincipalSource = $errorMessage
                }

                $remoteLocalGroupsMembershipArray.Add($object)

                continue
            }
        }
        
        $adsi.psbase.children | Where-Object { $_.psbase.schemaClassName -eq 'group' } | ForEach-Object {
            $group = $_.name
            $groupName = $group.Tostring()
            $localGroup = [ADSI]"WinNT://$computer/$group,group"
            $members = @($localgroup.psbase.Invoke('Members'))
                                    
            if ($members) {
                foreach ($member In $members) {
                    $path = $null

                    $name = $member.GetType().InvokeMember('Name', 'GetProperty', $null, $Member, $null)
                    $path = $member.GetType().InvokeMember('ADsPath', 'GetProperty', $null, $Member, $null)
                    $memberType = $member.GetType().InvokeMember('Class', 'GetProperty', $null, $Member, $null)
                    
                    if (($path -like "*/$computer/*") -Or ($path -like 'WinNT://NT*')) {
                        $principalSource = 'Local'
                    }
                    elseif ($path -like 'WinNT://AzureAD/*') {
                        $principalSource = 'AzureAD'
                    }
                    elseif ($path -like 'WinNT://S-1*') {
                        $principalSource = 'Problably AzureAD'
                    }
                    else {
                        $principalSource = 'ActiveDirectory'
                    }
                        
                    $object = [PSCustomObject][ordered]@{
                        Computername          = $Computer
                        GroupName             = $groupName
                        GroupDescription      = $($localGroup.Description)
                        MemberName            = $name
                        MemberType            = $memberType
                        MemberPath            = $path
                        MemberPrincipalSource = $principalSource
                    }

                    $remoteLocalGroupsMembershipArray.Add($object)
                }
            }
            else {
                $object = [PSCustomObject][ordered]@{
                    Computername          = $Computer
                    GroupName             = $GName
                    GroupDescription      = $($localGroup.Description)
                    MemberName            = '-'
                    MemberType            = '-'
                    MemberPath            = '-'
                    MemberPrincipalSource = '-'
                }

                $remoteLocalGroupsMembershipArray.Add($object)
            }
        }
    }

    return $remoteLocalGroupsMembershipArray
}