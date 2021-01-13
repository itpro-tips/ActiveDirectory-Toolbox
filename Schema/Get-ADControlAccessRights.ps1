################################################################################################
# Get-ADControlAccessRights.ps1
# 
# AUTHOR: Robin Granberg (robin.granberg@microsoft.com)
#
# THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
# FITNESS FOR A PARTICULAR PURPOSE.
#
# This sample is not supported under any Microsoft standard support program or service. 
# The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
# implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose. The entire risk arising out of the use or performance
# of the sample and documentation remains with you. In no event shall Microsoft, its authors,
# or anyone else involved in the creation, production, or delivery of the script be liable for 
# any damages whatsoever (including, without limitation, damages for loss of business profits, 
# business interruption, loss of business information, or other pecuniary loss) arising out of 
# the use of or inability to use the sample or documentation, even if Microsoft has been advised 
# of the possibility of such damages.
################################################################################################


param([string]$CAR = "*",
    [ValidateSet(“CONTROL”, ”PROP”, ”SELF”)] 
    [String] 
    $Type = "" ,
    [string]$ApplyTo,
    [switch]$SkipProperty,
    [string]$Attribute = "",
    [switch]$help)
    
$strScriptName = $($MyInvocation.MyCommand.Name)

function funHelp() {
    clear
    $helpText = @"
################################################################################################
# $strScriptName 
# 
# AUTHOR: Robin Granberg (robin.granberg@microsoft.com)
#
# THIS CODE-SAMPLE IS PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED 
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR 
# FITNESS FOR A PARTICULAR PURPOSE.
#
# This sample is not supported under any Microsoft standard support program or service. 
# The script is provided AS IS without warranty of any kind. Microsoft further disclaims all
# implied warranties including, without limitation, any implied warranties of merchantability
# or of fitness for a particular purpose. The entire risk arising out of the use or performance
# of the sample and documentation remains with you. In no event shall Microsoft, its authors,
# or anyone else involved in the creation, production, or delivery of the script be liable for 
# any damages whatsoever (including, without limitation, damages for loss of business profits, 
# business interruption, loss of business information, or other pecuniary loss) arising out of 
# the use of or inability to use the sample or documentation, even if Microsoft has been advised 
# of the possibility of such damages.
################################################################################################
DESCRIPTION:
NAME: $strScriptName
Displays information about Control Access Rights


PARAMETERS:

-CAR           Name of Control Access Rights. DisplayName value of Control Access Rights. (Optional)
-ApplyTo       Filter on CAR that apply to a specific object type. (Optional)
-Type          Define type for CAR to display: CONTROl, PROP, SELF. (Optional)
               CONTROl = Control Access
               PROP = Property Sets
               SELF = Validated Writes
-SkipProperty  Don't display properties that's included in property sets. (Optional)
-help          Prints the HelpFile (Optional)

SYNTAX:

Example 1:

.\$strScriptName   -CAR "Personal Information"

Displays information about the property set Personal Information.

Example 2:

.\$strScriptName   -CAR "*"

Displays information about all Control Access Rights.

Example 3:

.\$strScriptName   -ApplyTo Computer

Displays information about all Control Access Rights that apply to computer object.

Example 4:

.\$strScriptName   -ApplyTo Computer -Type CONTROL

Displays information about all Control Access Rights that apply to computer object and are control access rights.

Example 5:

.\$strScriptName   -Help

Displays the help topic for the script


"@
    write-host $helpText -foregroundcolor white
    exit
}


#==========================================================================
# Function		: MapGUIDToMatchingName
# Arguments     : Object Guid or Rights Guid
# Returns   	: LDAPDisplayName or DisplayName
# Description   : Searches in the dictionaries(Hash) dicRightsGuids and $global:dicSchemaIDGUIDs  and in Schema 
#				for the name of the object or Extended Right, if found in Schema the dicRightsGuids is updated.
#				Then the functions return the name(LDAPDisplayName or DisplayName).
#==========================================================================
Function MapGUIDToMatchingName {
    Param([string] $strGUIDAsString, [string] $Domain)
    [string] $strOut = ""
    [string] $objSchemaRecordset = ""
    [string] $strLDAPname = ""

    If ($strGUIDAsString -eq "") {

        Break
    }
    $strGUIDAsString = $strGUIDAsString.toUpper()
    $strOut = ""
    if ($global:dicRightsGuids.ContainsKey($strGUIDAsString)) {
        $strOut = $global:dicRightsGuids.Item($strGUIDAsString)
    }

    If ($strOut -eq "") {
        #Didn't find a match in extended rights
		
        if ($strGUIDAsString -match ("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")) {
		 	
            $ConvertGUID = ConvertGUID($strGUIDAsString)

            # Connect to RootDSE
            $rootDSE = [ADSI]"LDAP://RootDSE"
            #Connect to the Configuration Naming Context
            $schemaSearchRoot = [ADSI]("LDAP://" + $rootDSE.Get("schemaNamingContext"))

            $searcher = new-object System.DirectoryServices.DirectorySearcher($schemaSearchRoot)
            $searcher.PropertiesToLoad.addrange(('cn', 'name', 'distinguishedNAme', 'lDAPDisplayName'))
            $searcher.filter = "(&(schemaIDGUID=$ConvertGUID))"
            $Object = $searcher.FindOne()
            if ($Object) {
                $objSchemaObject = $Object.Properties
                $strLDAPname = $objSchemaObject.item("lDAPDisplayName")[0]
                $strOut = $strLDAPname
            }
        }
	  
    }
    
    return $strOut
}
#==========================================================================
# Function		: ConvertGUID
# Arguments     : Object Guid or Rights Guid
# Returns   	: AD Searchable GUID String
# Description   : Convert a GUID to a string

#==========================================================================
function ConvertGUID($guid) {
 
    $test = "(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})(.{2})"
    $pattern = '"\$4\$3\$2\$1\$6\$5\$8\$7\$9\$10\$11\$12\$13\$14\$15\$16"'
    $ConvertGUID = [regex]::Replace($guid.replace("-", ""), $test, $pattern).Replace("`"", "")
    return $ConvertGUID
}


Function RunCheck() {
    Param($propset, $type, $intType)

    [void][Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.Protocols")

    $rootDSE = [adsi]"LDAP://RootDSE"
    $global:strDC = $rootDSE.dnsHostName
    $LDAPConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection($rootDSE.dnsHostName)
    $request = New-Object System.directoryServices.Protocols.SearchRequest("CN=Extended-Rights,$($rootDSE.configurationNamingContext)", "(&(objectClass=controlAccessRight)(displayName=$propset))", "Subtree")
    [void]$request.Attributes.Add("appliesTo")
    [void]$request.Attributes.Add("rightsGuid")
    [void]$request.Attributes.Add("name")
    [void]$request.Attributes.Add("ldapdisplayname")
    [void]$request.Attributes.Add("displayname")
    [void]$request.Attributes.Add("distinguishedName")
    [void]$request.Attributes.Add("validAccesses")
    $response = $LDAPConnection.SendRequest($request)
    $adObject = $response.Entries

    $sd = New-Object System.Collections.ArrayList
    foreach ($entry  in $response.Entries) {
        if ($Attribute -ne "") {

            $global:i = 0 
            $arrAttrib = ""
            $bolFound = $false
            $arrAttrib = GetattributeSecurityGUID $entry.Attributes.rightsguid[0].ToString() 
            foreach ($strAttrib in $arrAttrib) {
                if ($Attribute -eq $strAttrib) {                                    
                    $bolFound = $true
                }
            }
            if ($bolFound) {
                write-output "=============================="
                write-output $entry.Attributes.name[0] 
                write-output "Displayname: $($entry.Attributes.displayname[0])"
                write-output $entry.distinguishedName
                if ($entry.Attributes.validaccesses[0] -eq 8)
                { $strStatus = "VALIDATED WRITE" }     
                if ($entry.Attributes.validaccesses[0] -eq 48)
                { $strStatus = "PROPERTY SET" }
                if ($entry.Attributes.validaccesses[0] -eq 256)
                { $strStatus = "CONTROL ACCESS RIGHT" }
                write-output $strStatus

                $index = 0
                while ($index -le $entry.Attributes.appliesto.count - 1) {
                    write-output "Applies to: $(MapGUIDToMatchingName -strGUIDAsString $entry.Attributes.appliesto[$index].toString() )"
                    $index++
                }
                write-output "GUID: $($entry.Attributes.rightsguid[0].ToString())"
                foreach ($strAttrib in $arrAttrib) {
                    write-output "Attributes: $strAttrib"
                    $global:i++
                }
            }
           
        }
        else {
            if ($ApplyTo) {
                $bolMatch = $false
                $indexOuter = 0
                while ($indexOuter -le $entry.Attributes.appliesto.count - 1) {

                    if ($(MapGUIDToMatchingName -strGUIDAsString $entry.Attributes.appliesto[$indexOuter].toString()) -eq $ApplyTo) {
                        $bolMatch = $true
                    }
                    $indexOuter++
                    if ($bolMatch) {
                        if ($TYPE -ne "") {
                            if ($entry.Attributes.validaccesses[0] -eq $intType) {
                                write-output "=============================="
                                write-out $entry.Attributes.name[0]# 
                                write-output "Displayname: $($entry.Attributes.displayname[0])"
                                write-out $entry.distinguishedName
                                if ($entry.Attributes.validaccesses[0] -eq 8)
                                { $strStatus = "VALIDATED WRITE" }     
                                if ($entry.Attributes.validaccesses[0] -eq 48)
                                { $strStatus = "PROPERTY SET" }
                                if ($entry.Attributes.validaccesses[0] -eq 256)
                                { $strStatus = "CONTROL ACCESS RIGHT" }
                                write-out $strStatus

                                $index = 0
                                while ($index -le $entry.Attributes.appliesto.count - 1) {
                                    write-out "Applies to: $(MapGUIDToMatchingName -strGUIDAsString $entry.Attributes.appliesto[$index].toString() )"
                                    $index++
                                }
                                write-out "GUID: $($entry.Attributes.rightsguid[0].ToString())"
                                $global:i = 0 
                                if (!($SkipProperty)) {
                                    $arrAttrib = GetattributeSecurityGUID $entry.Attributes.rightsguid[0].ToString() 
                                    foreach ($strAttrib in $arrAttrib) {
                                        write-output "Attributes: $strAttrib"
                                        $global:i++
                                    }
                                    write-output "Total Attributes:$global:i"
                                }
                            }#End if intType
                        }#else inf Type
                        else {
                            write-output "=============================="
                            write-output $entry.Attributes.name[0] 
                            write-output "Displayname: $($entry.Attributes.displayname[0])"
                            write-output $entry.distinguishedName
                            if ($entry.Attributes.validaccesses[0] -eq 8)
                            { $strStatus = "VALIDATED WRITE" }     
                            if ($entry.Attributes.validaccesses[0] -eq 48)
                            { $strStatus = "PROPERTY SET" }
                            if ($entry.Attributes.validaccesses[0] -eq 256)
                            { $strStatus = "CONTROL ACCESS RIGHT" }
                            write-output $strStatus

                            $index = 0
                            while ($index -le $entry.Attributes.appliesto.count - 1) {
                                write-output "Applies to: $(MapGUIDToMatchingName -strGUIDAsString $entry.Attributes.appliesto[$index].toString() )"
                                $index++
                            }
                            write-output "GUID: $($entry.Attributes.rightsguid[0].ToString())"
                            $global:i = 0 
                            if (!($SkipProperty)) {
                                $arrAttrib = GetattributeSecurityGUID $entry.Attributes.rightsguid[0].ToString() 
                                foreach ($strAttrib in $arrAttrib) {
                                    write-output "Attributes: $strAttrib"
                                    $global:i++
                                }
                                write-output "Total Attributes:$global:i"
                            }
                        }#End inf Type
                    }#End bolMatch
                }#End while looking for apply to
            }
            else {
                if ($TYPE -ne "") {
                    if ($entry.Attributes.validaccesses[0] -eq $intType) {
                        write-output "=============================="
                        write-output $entry.Attributes.name[0] 
                        write-output "Displayname: $($entry.Attributes.displayname[0])"
                        write-output $entry.distinguishedName
                        if ($entry.Attributes.validaccesses[0] -eq 8)
                        { $strStatus = "VALIDATED WRITE" }     
                        if ($entry.Attributes.validaccesses[0] -eq 48)
                        { $strStatus = "PROPERTY SET" }
                        if ($entry.Attributes.validaccesses[0] -eq 256)
                        { $strStatus = "CONTROL ACCESS RIGHT" }
                        write-output $strStatus

                        $index = 0
                        while ($index -le $entry.Attributes.appliesto.count - 1) {
                            write-output "Applies to: $(MapGUIDToMatchingName -strGUIDAsString $entry.Attributes.appliesto[$index].toString() )"
                            $index++
                        }
                        write-output "GUID: $($entry.Attributes.rightsguid[0].ToString())"
                        $global:i = 0 
                        if (!($SkipProperty)) {
                            $arrAttrib = GetattributeSecurityGUID $entry.Attributes.rightsguid[0].ToString() 
                            foreach ($strAttrib in $arrAttrib) {
                                write-output "Attributes: $strAttrib"
                                $global:i++
                            }
                            write-output "Total Attributes:$global:i"
                        }
                    }#End if intType
                }#else inf Type
                else {
                    write-output "=============================="
                    write-output $entry.Attributes.name[0] 
                    write-output "Displayname: $($entry.Attributes.displayname[0])"
                    write-output $entry.distinguishedName
                    if ($entry.Attributes.validaccesses[0] -eq 8)
                    { $strStatus = "VALIDATED WRITE" }     
                    if ($entry.Attributes.validaccesses[0] -eq 48)
                    { $strStatus = "PROPERTY SET" }
                    if ($entry.Attributes.validaccesses[0] -eq 256)
                    { $strStatus = "CONTROL ACCESS RIGHT" }
                    write-output $strStatus

                    $index = 0
                    while ($index -le $entry.Attributes.appliesto.count - 1) {
                        write-output "Applies to: $(MapGUIDToMatchingName -strGUIDAsString $entry.Attributes.appliesto[$index].toString() )"
                        $index++
                    }
                    write-output "GUID: $($entry.Attributes.rightsguid[0].ToString())"
                    $global:i = 0 
                    if (!($SkipProperty)) {
                        $arrAttrib = GetattributeSecurityGUID $entry.Attributes.rightsguid[0].ToString() 
                        foreach ($strAttrib in $arrAttrib) {
                            write-output "Attributes: $strAttrib"
                            $global:i++
                        }
                        write-output "Total Attributes:$global:i"

                    }
                }#End inf Type
            }#End if Applyto
        }#End if Attribute
    }#End foreach Entry
}
Function GetattributeSecurityGUID() {
    Param($rightsGUID)
    $arrAttributes = New-Object system.collections.arraylist
    [void][Reflection.Assembly]::LoadWithPartialName("System.DirectoryServices.Protocols")
    [string] $LDAP_SERVER_SHOW_DELETED_OID = "1.2.840.113556.1.4.417"
    $PageSize = 100
    $TimeoutSeconds = 120
    $rootDSE = [adsi]"LDAP://RootDSE"
    $LDAPConnection = New-Object System.DirectoryServices.Protocols.LDAPConnection($rootDSE.dnsHostName)
    $request = New-Object System.directoryServices.Protocols.SearchRequest($rootDSE.schemaNamingContext, "(&(objectClass=attributeSchema)(attributeSecurityGUID=*))", "Subtree")
    [void]$request.Controls.Add((New-Object "System.DirectoryServices.Protocols.DirectoryControl" -ArgumentList "$LDAP_SERVER_SHOW_DELETED_OID", $null, $false, $true ))
    [System.DirectoryServices.Protocols.PageResultRequestControl]$pagedRqc = new-object System.DirectoryServices.Protocols.PageResultRequestControl($pageSize)
    $request.Controls.Add($pagedRqc) | Out-Null
    [void]$request.Attributes.Add("attributeSecurityGUID")
    [void]$request.Attributes.Add("name")
    [void]$request.Attributes.Add("ldapdisplayname")
    [void]$request.Attributes.Add("distinguishedName")

    $arrSchemaObjects = New-Object System.Collections.ArrayList
    while ($true) {
        $response = $LdapConnection.SendRequest($request, (new-object System.Timespan(0, 0, $TimeoutSeconds))) -as [System.DirectoryServices.Protocols.SearchResponse];
                
        #for paged search, the response for paged search result control - we will need a cookie from result later
        if ($pageSize -gt 0) {
            [System.DirectoryServices.Protocols.PageResultResponseControl] $prrc = $null;
            if ($response.Controls.Length -gt 0) {
                foreach ($ctrl in $response.Controls) {
                    if ($ctrl -is [System.DirectoryServices.Protocols.PageResultResponseControl]) {
                        $prrc = $ctrl;
                        break;
                    }
                }
            }
            if ($null -eq $prrc) {
                #server was unable to process paged search
                throw "Find-LdapObject: Server failed to return paged response for request $SearchFilter"
            }
        }
        #now process the returned list of distinguishedNames and fetch required properties using ranged retrieval
        $colResults = $response.Entries
        foreach ($objResult in $colResults) { 

            if (([guid]$objResult.attributes.attributesecurityguid[0]).ToString().ToUpper() -eq $rightsGUID) {
                [void]$arrAttributes.add($($objResult.Attributes.ldapdisplayname[0].ToString()))
            }
        }
        if ($pageSize -gt 0) {
            if ($prrc.Cookie.Length -eq 0) {
                #last page --> we're done
                break;
            }
            #pass the search cookie back to server in next paged request
            $pagedRqc.Cookie = $prrc.Cookie;
        }
        else {
            #exit the processing for non-paged search
            break;
        }
    }#End While
    return $arrAttributes
}

if ($help) {
    funHelp

}

$global:dicRightsGuids = @{"value" = "1" }
Switch ($Type) {
    "CONTROL"
    { $intType = 256 }
    "PROP"
    { $intType = 48 }
    "SELF"
    { $intType = 8 }
    default
    { }
}
 
if ($CAR.Length -gt 0) {
    RunCheck $CAR $Type $intType
}
else {

}

