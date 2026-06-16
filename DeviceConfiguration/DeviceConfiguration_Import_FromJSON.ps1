Import-Module Microsoft.Graph.DeviceManagement

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

# Prompting for the JSON file path and validating it exists and contains valid JSON
do {
    $ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"

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

# Importing JSON file
$JsonPolicyBody = Get-Content -LiteralPath $ImportPath -Raw

## Converting JSON to a hashtable
$Policy = $JsonPolicyBody | ConvertFrom-Json -AsHashtable

if ($Policy.ContainsKey('AdditionalProperties') -and $Policy.AdditionalProperties.'@odata.type') {
    $RequestBody = $Policy.AdditionalProperties
    if (-not $RequestBody.ContainsKey('displayName')) {
        $RequestBody['displayName'] = $Policy.DisplayName
    }
}
else {
    $RequestBody = $Policy
}

if (-not $RequestBody.'@odata.type') {
    Write-Host "The JSON file is missing the required '@odata.type' property (e.g. '#microsoft.graph.windows10GeneralConfiguration')." -ForegroundColor Red
    Write-Host "Ensure the file was produced by DeviceConfiguration_Export.ps1. Script can't continue..." -ForegroundColor Red
    break
}

## Graph requires every OData type to be prefixed with '#'. Without it the service returns
## "Invalid OData type specified". Normalise the top-level type and any nested types so the
## file imports whether or not the '#' was present.
function Set-ODataTypePrefix {
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

Set-ODataTypePrefix -Node $RequestBody

## Removing read-only properties that the service rejects on create
foreach ($ReadOnlyProperty in 'id', 'createdDateTime', 'lastModifiedDateTime', 'version', 'supportsScopeTags') {
    $RequestBody.Remove($ReadOnlyProperty)
}

$DisplayName = $RequestBody['displayName']
Write-Host "Device Configuration Policy '$DisplayName' Found..." -ForegroundColor Yellow

## Displaying the policy settings
$RequestBody

Write-Host "Adding Device Configuration Policy '$DisplayName'" -ForegroundColor Yellow

## Creating the policy in Intune - using Invoke-MgGraphRequest so the '@odata.type'
## discriminator is sent and Graph creates the correct concrete type.
$CreateResult = Invoke-MgGraphRequest -Method POST `
    -Uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations" `
    -Body ($RequestBody | ConvertTo-Json -Depth 20)

Write-Host "Policy created with id" $CreateResult.id -ForegroundColor Green