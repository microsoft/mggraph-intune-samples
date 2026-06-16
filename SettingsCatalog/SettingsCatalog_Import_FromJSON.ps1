Import-Module Microsoft.Graph.Beta.DeviceManagement

####################################################

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0

The PowerShell SDK supports two types of authentication: delegated access, and app-only access.

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal

#>

#endregion

####################################################

Function Get-TargetResource() {

<#
.SYNOPSIS
Determines which Graph endpoint a policy JSON object should be imported to
.DESCRIPTION
This script handles the Settings Catalog policy type as well as the additional
policy types that branched out of the Settings Catalog (resource access profiles
and hardware configurations). Each uses a different schema, so the correct target
endpoint is detected from the shape of the imported object.
.NOTES
NAME: Get-TargetResource
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Collections.IDictionary]$Policy
    )

    # Settings Catalog policies carry a settings collection and the technologies/platforms discriminators
    if ($Policy.Contains('settings') -or $Policy.Contains('technologies')) {
        return "deviceManagement/configurationPolicies"
    }

    # Hardware configurations carry a configuration file payload and format
    if ($Policy.Contains('hardwareConfigurationFormat') -or $Policy.Contains('configurationFileContent')) {
        return "deviceManagement/hardwareConfigurations"
    }

    # Resource access profiles are @odata.type discriminated (Wi-Fi, VPN, certificate, trusted root)
    $odataType = $Policy['@odata.type']
    if ($odataType -and $odataType -match 'windows10X|ResourceAccess') {
        return "deviceManagement/resourceAccessProfiles"
    }

    return $null

}

####################################################

Function Set-ODataTypePrefix() {

    <#
.SYNOPSIS
Ensures every '@odata.type' value is prefixed with '#'
.DESCRIPTION
Graph requires every OData type discriminator to be prefixed with '#'. Without it
the service returns "Invalid OData type specified". This normalises the top-level
type and any nested types so the file imports whether or not the '#' was present.
.NOTES
NAME: Set-ODataTypePrefix
#>

    param ($Node)

    if ($Node -is [System.Collections.IDictionary]) {
        if ($Node.Contains('@odata.type') -and $Node['@odata.type'] -is [string] -and $Node['@odata.type'] -notlike '#*') {
            $Node['@odata.type'] = '#' + $Node['@odata.type']
        }
        foreach ($Value in @($Node.Values)) {
            Set-ODataTypePrefix -Node $Value
        }
    }
    elseif ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
        foreach ($Item in $Node) {
            Set-ODataTypePrefix -Node $Item
        }
    }

}

####################################################

# Prompting for the JSON file path and validating it exists and contains valid JSON
do {
    $ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\policy.json"

    # Replacing quotes for Test-Path (handles paths pasted with surrounding quotes)
    $ImportPath = $ImportPath.Replace('"', '').Trim()
    $PathValid = $false

    if ([string]::IsNullOrWhiteSpace($ImportPath)) {
        Write-Host "No path was provided. Please try again..." -ForegroundColor Yellow
    }
    # Checking the path points to an existing file (not a folder)
    elseif (!(Test-Path -LiteralPath $ImportPath -PathType Leaf)) {
        Write-Host "Import path '$ImportPath' doesn't exist or isn't a file. Please try again..." -ForegroundColor Yellow
    }
    # Validating the file contains well-formed JSON
    elseif (!(Get-Content -LiteralPath $ImportPath -Raw | Test-Json -ErrorAction SilentlyContinue)) {
        Write-Host "File '$ImportPath' doesn't contain valid JSON. Please try again..." -ForegroundColor Yellow
    }
    else {
        $PathValid = $true
    }
}
while (-not $PathValid)

####################################################

# Importing JSON file and converting to a hashtable so properties can be edited
$JsonPolicyBody = Get-Content -LiteralPath $ImportPath -Raw
$RequestBody = $JsonPolicyBody | ConvertFrom-Json -AsHashtable

# Determining which endpoint this policy should be imported to
$Resource = Get-TargetResource -Policy $RequestBody

if (-not $Resource) {
    Write-Host "Unable to determine the policy type from the JSON file." -ForegroundColor Red
    Write-Host "Ensure the file was produced by SettingsCatalog_Export.ps1 and is a Settings Catalog policy, resource access profile, or hardware configuration. Script can't continue..." -ForegroundColor Red
    break
}

# Normalising OData type discriminators (resource access profiles require '#')
Set-ODataTypePrefix -Node $RequestBody

# Removing read-only and navigation properties that the service rejects on create.
# Nested values (e.g. Settings Catalog settingInstances) are left untouched.
$ReadOnlyProperties = @(
    'id', 'createdDateTime', 'creationDateTime', 'lastModifiedDateTime', 'version',
    'settingCount', 'creationSource', 'priorityMetaData', 'supportsScopeTags', 'isAssigned',
    'assignments', 'deviceRunStates', 'userRunStates', 'runSummary'
)

foreach ($Property in $ReadOnlyProperties) {
    if ($RequestBody.Contains($Property)) {
        $RequestBody.Remove($Property)
    }
}

# Removing OData annotations (e.g. @odata.context) while keeping the @odata.type discriminator
foreach ($Key in @($RequestBody.Keys)) {
    if ($Key -like '*@odata*' -and $Key -ne '@odata.type') {
        $RequestBody.Remove($Key)
    }
}

####################################################

$DisplayName = if ($RequestBody['name']) { $RequestBody['name'] } else { $RequestBody['displayName'] }
Write-Host "Policy '$DisplayName' found, importing to $Resource ..." -ForegroundColor Yellow

# Displaying the policy body that will be sent
$RequestBody

# Creating the policy in Intune - using Invoke-MgGraphRequest so the '@odata.type'
# discriminator is sent and Graph creates the correct concrete type.
$CreateResult = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/$Resource" `
    -Body ($RequestBody | ConvertTo-Json -Depth 20)

Write-Host "Policy created with id" $CreateResult.id -ForegroundColor Green
