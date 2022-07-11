function Get-RemoteLocalGroupsMembership {
    [CmdletBinding()]
    param (
        [Parameter()]
        [String[]]$ComputerName
    )

    [System.Collections.Generic.List[PSObject]]$remoteLocalGroupsMembershipArray = @()

    foreach ($computer in $computerName) {
    
        $adsi = [ADSI]"WinNT://$Computer,computer"

        try {
            # Test ADSI
            [void]$adsi.Tostring()
        }
        catch {
            $object = [PSCustomObject][ordered]@{
                Computername     = $Computer
                GroupName        = $_.Exception.Message
                GroupDescription = $_.Exception.Message
                MemberName       = $_.Exception.Message
                MemberPath       = $_.Exception.Message
                MemberType       = $_.Exception.Message
                PrincipalSource  = $_.Exception.Message
                isGroupMember    = $_.Exception.Message
            }

            $remoteLocalGroupsMembershipArray.Add($object)

            continue
        }
                
        foreach ($adsiObj in $adsi.psbase.children) {
            switch -regex($adsiObj.psbase.SchemaClassName) {
                "group" {
                    $group = $adsiObj.name
                    $localGroup = [ADSI]"WinNT://$computer/$group,group"
                    $members = @($localgroup.psbase.Invoke("Members"))
                        
                    $GName = $group.tostring()
                                    
                    if ($members) {
                        foreach ($member In $members) {
                            $name = $member.GetType().InvokeMember("Name", "GetProperty", $Null, $Member, $Null)
                            $path = $member.GetType().InvokeMember("ADsPath", "GetProperty", $Null, $Member, $Null)
                        
                            $isGroup = ($member.GetType().InvokeMember("Class", "GetProperty", $Null, $Member, $Null) -eq "group")
                            if (($path -like "*/$computer/*") -Or ($path -like "WinNT://NT*")) {
                                $principalSource = 'Local'
                            }
                            else { 
                                $principalSource = 'ActiveDirectory'
                            }
                        
                            $object = [PSCustomObject][ordered]@{
                                Computername     = $Computer
                                GroupName        = $GName
                                GroupDescription = $($localGroup.Description)
                                MemberName       = $name
                                MemberPath       = $path
                                MemberType       = $type
                                PrincipalSource  = $principalSource
                                isGroupMember    = $isGroup
                            }
                            $remoteLocalGroupsMembershipArray.Add($object)
                        }
                    }
                    else {
                        $object = [PSCustomObject][ordered]@{
                            Computername     = $Computer
                            GroupName        = $GName
                            GroupDescription = $($localGroup.Description)
                            MemberName       = '-'
                            MemberPath       = '-'
                            MemberType       = '-'
                            PrincipalSource  = '-'
                            isGroupMember    = '-'
                        }
                        $remoteLocalGroupsMembershipArray.Add($object)
                    }
                }
            }
        }
    }

    return $remoteLocalGroupsMembershipArray
}