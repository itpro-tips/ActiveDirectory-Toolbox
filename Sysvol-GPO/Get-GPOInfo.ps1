Function Get-GPOInfo {
    <#
.SYNOPSIS
    This function retrieves some informations about all the GPO's in a given domain.
.DESCRIPTION
    This function uses the GroupPolicy module to generate an XML report, parse it, analyse it, and put all the useful informations in a custom object.
.PARAMETER DomainName
    You can choose the domain to analyse.
    Defaulted to current domain.
.EXAMPLE
    Get-GPOInfo -Verbose | Out-GridView -Title "GPO Report"

    Display a nice table with all GPO's and their informations.
.EXAMPLE
    Get-GPOInfo | ? {$_.HasComputerSettings -and $_.HasUserSettings}

    GPO with both settings.
.EXAMPLE
    Get-GPOInfo | ? {$_.HasComputerSettings -and ($_.ComputerEnabled -eq $false)}

    GPO with computer settings configured, but disabled.
.EXAMPLE
    Get-GPOInfo | ? {$_.HasUserSettings -and ($_.UserEnabled -eq $false)}

    GPO with user settings configured, but disabled.
.EXAMPLE
    Get-GPOInfo | ? {$_.ComputerSettingsVersionDirectory -eq 0 -and $_.UserSettingsVersionDirectory -eq 0}

    Never modified GPO.
.EXAMPLE
    Get-GPOInfo | ? {$_.DirectoryAndSysvolVersionMatch -eq $false}

    Get GPO with problems between directory and sysvol version    
.EXAMPLE
    Get-GPOInfo | ? {$_.LinksTo -like '*domain.local*'}

    GPO links to specific OU.
    Used -like or -match because if link to several OU, LinksTo will be pipe '|' separated, ie: OU1|OU2
    
.EXAMPLE
    Get-GPOInfo | ? {$_.LinksTo -eq 'Unlinked'}

    Unlinked GPO.

#>
    [cmdletbinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateScript({ Test-Connection $_ -Count 1 -Quiet })]
        [String]$DomainName = $env:USERDNSDOMAIN
    )

    [System.Collections.Generic.List[PSCustomObject]]$gpoInfoArray = @()

    Write-Verbose -Message 'Importing Group Policy module...'

    try {
        Import-Module -Name GroupPolicy -Verbose:$false -ErrorAction stop
    }
    catch {
        Write-Warning -Message 'Failed to import GroupPolicy module'
        return $null
    }

    $GPOs = Get-GPO -All -Domain $DomainName
    
    foreach ($GPO in $GPOs) {
        Write-Verbose -Message "Processing $($GPO.DisplayName)..."

        [xml]$XmlGPReport = $GPO.generatereport('xml')

        [System.Collections.Generic.List[PSCustomObject]]$gpoACLsArray = @()

        $XmlGPReport.gpo.SecurityDescriptor.Permissions.TrusteePermissions | ForEach-Object -Process {
            $gpoPerms = "$($_.trustee.name.'#Text')#$($_.Standard.GPOGroupedAccessEnum)#$($_.type.PermissionType)#$($_.Inherited)"
            <#$gpoPerms = [PSCustomObject][ordered]@{
                'User'           = $_.trustee.name.'#Text'
                'PermissionType' = $_.type.PermissionType
                'Inherited'      = $_.Inherited
                'Permissions'    = $_.Standard.GPOGroupedAccessEnum
            }
            #>

            $gpoACLsArray.add($gpoPerms)
        }

        [System.Collections.Generic.List[PSCustomObject]]$linksToArray = @()

        if ($null -ne $XmlGPReport.GPO.LinksTo) {
            $XmlGPReport.GPO.LinksTo | ForEach-Object {
                $enforced = $false
                $enabled = $false

                if ($_.NoOverride -eq 'true') {
                    $enforced = $true
                }

                if ($_.Enabled -eq 'true') {
                    $enabled = $true
                }
            
                $linksTo = "$($_.SOMPath)#Enabled=$enabled#Enforced=$enforced"

                $linksToArray.add($linksTo)
            }
        }

        $object = [PSCustomObject][ordered]@{
            'Name'                             = $XmlGPReport.GPO.Name
            'LinksTo'                          = if ($null -ne $XmlGPReport.GPO.LinksTo) { (($XmlGPReport.GPO.LinksTo).SOMPath) -join '|' }else { 'Unlinked' }
            'Description'                      = $GPO.Description -replace "`t|`n|`r", "\n" # remove return char
            'GpoStatus'                        = $GPO.GpoStatus
            'UserSettingsEnabled'              = $XmlGPReport.GPO.User.Enabled
            'ComputerSettingsEnabled'          = $XmlGPReport.GPO.Computer.Enabled
            'UserSettingsVersionDirectory'     = $XmlGPReport.GPO.User.VersionDirectory
            'UserSettingsVersionSysvol'        = $XmlGPReport.GPO.User.VersionSysvol
            'ComputerSettingsVersionDirectory' = $XmlGPReport.GPO.Computer.VersionDirectory
            'ComputerSettingsVersionSysvol'    = $XmlGPReport.GPO.Computer.VersionSysvol
            'DirectoryAndSysvolVersionMatch'   = if ($XmlGPReport.GPO.User.VersionDirectory -eq $XmlGPReport.GPO.User.VersionSysvol -and $XmlGPReport.GPO.Computer.VersionDirectory -eq $XmlGPReport.GPO.Computer.VersionSysvol) { $true }else { $false }
            'HasComputerSettings'              = if ($null -eq $XmlGPReport.GPO.Computer.ExtensionData) { $false }else { $true }
            'HasUserSettings'                  = if ($null -eq $XmlGPReport.GPO.User.ExtensionData) { $false }else { $true }
            'CreationTime'                     = $GPO.CreationTime
            'ModificationTime'                 = $GPO.ModificationTime
            'GUID'                             = $GPO.Id
            'WMIFilter'                        = $GPO.WmiFilter.name
            'WMIFilterDescription'             = $GPO.WmiFilter.Description
            'Path'                             = $GPO.Path
            'Id'                               = $GPO.Id
            'LinksToDetails'                   = $linksToArray -join '|'
            'ACLs'                             = $gpoACLsArray -join '|'
            'SDDL'                             = $XmlGPReport.GPO.SecurityDescriptor.SDDL.'#text'
        }

        $gpoInfoArray.Add($object)
    }

    return $gpoInfoArray
}