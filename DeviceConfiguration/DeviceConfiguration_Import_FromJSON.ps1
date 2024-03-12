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
$FileName = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"

Test-Json -Path $FileName

If (Test-Path -Path $FileName -Type Leaf) {
    $ImportPath = $FileName
}
Else {
    $ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"
}

# Replacing quotes for Test-Path
$ImportPath = $ImportPath.replace('"', '')

if (!(Test-Path "$ImportPath")) {

    Write-Host "Import Path for JSON file doesn't exist..." -ForegroundColor Red
    Write-Host "Script can't continue..." -ForegroundColor Red
    Write-Host
    break

}

####################################################

$JSON_Data = Get-Content -Path "$ImportPath"

$JSON_Convert = ($JSON_Data | ConvertFrom-Json -AsHashtable).AdditionalProperties

$DisplayName = ($JSON_Data | ConvertFrom-Json).DisplayName

write-host
write-host "Device Configuration Policy '$DisplayName' Found..." -ForegroundColor Yellow
write-host
$JSON_Output
write-host
Write-Host "Adding Device Configuration Policy '$DisplayName'" -ForegroundColor Yellow
New-MgDeviceManagementDeviceConfiguration -DisplayName $DisplayName -AdditionalProperties $JSON_Convert