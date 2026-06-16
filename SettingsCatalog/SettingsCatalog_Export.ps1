Import-Module Microsoft.Graph.Beta.DeviceManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>
Function Get-SettingsCatalogPolicy() {

<#
.SYNOPSIS
This function is used to get Settings Catalog policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Settings Catalog policies
.EXAMPLE
Get-SettingsCatalogPolicy
Returns any Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform windows10
Returns any Windows 10 Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform macOS
Returns any MacOS Settings Catalog policies configured in Intune
.NOTES
NAME: Get-SettingsCatalogPolicy
#>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $false)]
        [ValidateSet("windows10", "windows10X", "macOS", "iOS", "android", "androidEnterprise", "aosp", "linux", "visionOS", "tvOS")]
        [ValidateNotNullOrEmpty()]
        [string]$Platform
    )

    $graphApiVersion = "beta"

    # The 'technologies' value scopes which settings catalog policies are returned. This sample
    # uses 'mdm', which covers the most common settings catalog policies. Other technologies are
    # also backed by the configurationPolicies endpoint - for example: endpointPrivilegeManagement
    # (EPM), enrollment (Autopilot device preparation), windowsOsRecovery, exchangeOnline, and
    # microsoftSense. If you need to export those, change or remove the "technologies has 'mdm'"
    # filter below (e.g. "technologies has 'endpointPrivilegeManagement'" or drop the filter
    # entirely to return every configuration policy regardless of technology).
    if ($Platform) {
        
        $Resource = "deviceManagement/configurationPolicies?`$filter=platforms has '$Platform' and technologies has 'mdm'"

    }

    else {

        $Resource = "deviceManagement/configurationPolicies?`$filter=technologies has 'mdm'"

    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

        $Response = Invoke-MgGraphRequest -Uri $uri -Method Get

        $AllResponses = $Response.value
        $ResponseNextLink = $Response."@odata.nextLink"

        # Following @odata.nextLink so all pages are returned, not just the first page
        while ($null -ne $ResponseNextLink) {

            $Response = Invoke-MgGraphRequest -Uri $ResponseNextLink -Method Get
            $ResponseNextLink = $Response."@odata.nextLink"
            $AllResponses += $Response.value

        }

        return $AllResponses

    }

    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break

    }

}

####################################################

Function Get-SettingsCatalogPolicySettings() {

    <#
.SYNOPSIS
This function is used to get Settings Catalog policy Settings from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Settings Catalog policy Settings
.EXAMPLE
Get-SettingsCatalogPolicySettings -policyid policyid
Returns any Settings Catalog policy Settings configured in Intune
.NOTES
NAME: Get-SettingsCatalogPolicySettings
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $policyid
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$policyid')/settings?`$expand=settingDefinitions"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

        $Response = (Invoke-MgGraphRequest -Uri $uri -Method Get)

        $AllResponses = $Response.value
     
        $ResponseNextLink = $Response."@odata.nextLink"

        while ($ResponseNextLink -ne $null) {

            $Response = (Invoke-MgGraphRequest -Uri $ResponseNextLink  -Method Get)
            $ResponseNextLink = $Response."@odata.nextLink"
            $AllResponses += $Response.value

        }

        return $AllResponses

    }

    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break

    }

}

####################################################

Function Export-JSONData() {

    <#
.SYNOPSIS
This function is used to export JSON data returned from Graph
.DESCRIPTION
This function is used to export JSON data returned from Graph
.EXAMPLE
Export-JSONData -JSON $JSON
Export the JSON inputted on the function
.NOTES
NAME: Export-JSONData
#>

    param (

        $JSON,
        $ExportPath
    )

    try {

        if ($JSON -eq "" -or $JSON -eq $null) {

            write-host "No JSON specified, please specify valid JSON..." -f Red

        }

        elseif (!$ExportPath) {

            write-host "No export path parameter set, please provide a path to export the file" -f Red

        }

        elseif (!(Test-Path $ExportPath)) {

            write-host "$ExportPath doesn't exist, can't export JSON Data" -f Red

        }

        else {

            $JSON1 = ConvertTo-Json $JSON -Depth 20

            $JSON_Convert = $JSON1 | ConvertFrom-Json

            # Settings Catalog policies use 'name'; the additional policy types
            # (resource access profiles, hardware configurations) use 'displayName'
            $DisplayName = if ($JSON_Convert.name) { $JSON_Convert.name } else { $JSON_Convert.displayName }

            # Updating display name to follow file naming conventions - https://msdn.microsoft.com/en-us/library/windows/desktop/aa365247%28v=vs.85%29.aspx
            $DisplayName = $DisplayName -replace '\<|\>|:|"|/|\\|\||\?|\*', "_"

            $FileName_JSON = "$DisplayName" + "_" + $(get-date -f dd-MM-yyyy-H-mm-ss) + ".json"

            write-host "Export Path:" "$ExportPath"

            $JSON1 | Set-Content -LiteralPath "$ExportPath\$FileName_JSON"
            write-host "JSON created in $ExportPath\$FileName_JSON..." -f cyan
            
        }

    }

    catch {

        $_.Exception

    }

}

####################################################

Function Get-IntuneResourceCollection() {

    <#
.SYNOPSIS
Gets all items from a Graph collection endpoint, following @odata.nextLink paging
.DESCRIPTION
Used to retrieve the additional policy types that branched out of the Settings Catalog
(resource access profiles, hardware configurations) which live on their own endpoints
.EXAMPLE
Get-IntuneResourceCollection -Resource "deviceManagement/resourceAccessProfiles"
.NOTES
NAME: Get-IntuneResourceCollection
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Resource
    )

    $graphApiVersion = "beta"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $Response = Invoke-MgGraphRequest -Uri $uri -Method Get

        $AllResponses = $Response.value
        $ResponseNextLink = $Response."@odata.nextLink"

        while ($null -ne $ResponseNextLink) {

            $Response = Invoke-MgGraphRequest -Uri $ResponseNextLink -Method Get
            $ResponseNextLink = $Response."@odata.nextLink"
            $AllResponses += $Response.value

        }

        return $AllResponses

    }

    catch {

        $ex = $_.Exception
        Write-Host "Request to $uri failed with HTTP Status $($ex.Response.StatusCode): $($ex.Message)" -ForegroundColor Red
        return $null

    }

}

####################################################

Function Get-IntuneResourceObject() {

    <#
.SYNOPSIS
Gets a single object by id from a Graph collection endpoint
.DESCRIPTION
Re-fetches an individual policy object so all properties are returned for export
.EXAMPLE
Get-IntuneResourceObject -Resource "deviceManagement/hardwareConfigurations" -Id $id
.NOTES
NAME: Get-IntuneResourceObject
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Resource,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Id
    )

    $graphApiVersion = "beta"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
        return Invoke-MgGraphRequest -Uri $uri -Method Get

    }

    catch {

        $ex = $_.Exception
        Write-Host "Request to $uri failed with HTTP Status $($ex.Response.StatusCode): $($ex.Message)" -ForegroundColor Red
        return $null

    }

}

####################################################

$ExportPath = Read-Host -Prompt "Please specify a path to export the policy data to e.g. C:\IntuneOutput"

# If the directory path doesn't exist prompt user to create the directory
$ExportPath = $ExportPath.replace('"', '')

if (!(Test-Path "$ExportPath")) {

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist, do you want to create this directory? Y or N?" -ForegroundColor Yellow

    $Confirm = read-host

    if ($Confirm -eq "y" -or $Confirm -eq "Y") {

        new-item -ItemType Directory -Path "$ExportPath" | Out-Null
        Write-Host

    }

    else {

        Write-Host "Creation of directory path was cancelled..." -ForegroundColor Red
        Write-Host
        break

    }

}

####################################################

$Policies = Get-SettingsCatalogPolicy

if ($Policies) {

    foreach ($policy in $Policies) {

        Write-Host $policy.name -ForegroundColor Yellow

        $AllSettingsInstances = @()

        $policyid = $policy.id
        $Policy_Technologies = $policy.technologies
        $Policy_Platforms = $Policy.platforms
        $Policy_Name = $Policy.name
        $Policy_Description = $policy.description

        $PolicyBody = New-Object -TypeName PSObject

        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'name' -Value "$Policy_Name"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'description' -Value "$Policy_Description"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'platforms' -Value "$Policy_Platforms"
        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'technologies' -Value "$Policy_Technologies"

        # Checking if policy has a templateId associated
        if ($policy.templateReference.templateId) {

            Write-Host "Found template reference" -f Cyan
            $templateId = $policy.templateReference.templateId

            $PolicyTemplateReference = New-Object -TypeName PSObject

            Add-Member -InputObject $PolicyTemplateReference -MemberType 'NoteProperty' -Name 'templateId' -Value $templateId

            Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'templateReference' -Value $PolicyTemplateReference

        }

        $SettingInstances = Get-SettingsCatalogPolicySettings -policyid $policyid

        $Instances = $SettingInstances.settingInstance

        foreach ($object in $Instances) {

            $Instance = New-Object -TypeName PSObject

            Add-Member -InputObject $Instance -MemberType 'NoteProperty' -Name 'settingInstance' -Value $object
            $AllSettingsInstances += $Instance

        }

        Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'settings' -Value @($AllSettingsInstances)

        Export-JSONData -JSON $PolicyBody -ExportPath "$ExportPath"
        Write-Host

    }

}

else {

    Write-Host "No Settings Catalog policies found..." -ForegroundColor Red
    Write-Host

}

####################################################
# Additional policy types that previously appeared under the Settings Catalog but
# now have their own endpoints. They use a different schema (full object with an
# '@odata.type' or a configuration file payload) rather than the configuration
# settings collection, so they are exported as complete objects. The matching
# import script (SettingsCatalog_Import_FromJSON.ps1) strips read-only properties
# and posts each object back to the correct endpoint.

$AdditionalResources = @(
    "deviceManagement/resourceAccessProfiles",
    "deviceManagement/hardwareConfigurations"
)

foreach ($Resource in $AdditionalResources) {

    Write-Host
    Write-Host "Checking $Resource ..." -ForegroundColor Cyan

    $Items = Get-IntuneResourceCollection -Resource $Resource

    if (-not $Items) {

        Write-Host "No items found at $Resource" -ForegroundColor DarkGray
        continue

    }

    foreach ($Item in $Items) {

        $DisplayName = if ($Item.name) { $Item.name } else { $Item.displayName }
        Write-Host $DisplayName -ForegroundColor Yellow

        # Re-fetch the individual object so all properties are returned for export
        $FullItem = Get-IntuneResourceObject -Resource $Resource -Id $Item.id

        if ($FullItem) {

            Export-JSONData -JSON $FullItem -ExportPath "$ExportPath"
            Write-Host

        }

    }

}