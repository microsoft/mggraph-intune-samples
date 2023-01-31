Import-Module Microsoft.Graph.Devices.CorporateManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 

#>

Select-MgProfile -Name v1.0

$AppConfigSelection = Read-Host -Prompt "What type of app configuration policy will be imported?
(Enter '1' for Managed Device or '2' for Managed App)"  

if ($AppConfigSelection -eq 1) {
    $AppConfigType = "ManagedDeviceAppConfig"

}
elseif ($AppConfigSelection -eq 2) {
    $AppConfigType = "ManagedAppConfig"
}
else {
    Write-Host "Unable to determine if JSON provided is a Managed App or Managed Device app config policy." -ForegroundColor Red
    Write-Host "Please try again and enter 1 for Managed Device App Config or 2 for Managed App App Config." -ForegroundColor Red
    break
}

$ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"


# Replacing quotes for Test-Path
$ImportPath = $ImportPath.replace('"', '')

# Check if the path exists
if (!(Test-Path "$ImportPath")) {
    Write-Host "Import Path for JSON file doesn't exist..." -ForegroundColor Red
    Write-Host "Script can't continue..." -ForegroundColor Red
    Write-Host
    break
}

#function to test if the JSON is valid
Function Test-JSON() {

    <#
    .SYNOPSIS
    This function is used to test if the JSON passed to a REST Post request is valid
    .DESCRIPTION
    The function tests if the JSON passed to the REST Post is valid
    .EXAMPLE
    Test-JSON -JSON $JSON
    Test if the JSON is valid before calling the Graph REST interface
    .NOTES
    NAME: Test-JSON
    #>
    
    param ( 
        $JSON  
    )
    
    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $validJson = $true  
    }
    
    catch {
        $validJson = $false
        $_.Exception
    }
    
    if (!$validJson) {
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }
}

$JSON_Data = Get-Content $ImportPath

# Excluding entries that are not required from imported JSON
$JSON_Convert = $JSON_Data | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, Version, deployedAppCount, Assignments, DeviceStatusSummary, DeviceStatuses, UserStatusSummary, UserStatuses

if ($AppConfigType -eq "ManagedAppConfig") {
    $JSON_Apps = $JSON_Convert.apps | Select-Object * -ExcludeProperty id, version
    $JSON_Convert | Add-Member -MemberType NoteProperty -Name 'apps' -Value @($JSON_Apps) -Force
}

$DisplayName = $JSON_Convert.displayName
$JSON_Output = $JSON_Convert | ConvertTo-Json -Depth 5

Test-Json -Json $JSON_Output

Write-Host
Write-Host "App Configuration Policy '$DisplayName' Found..." -ForegroundColor Cyan
Write-Host
$JSON_Output
Write-Host
Write-Host "Creating Policy..."
Write-Host

switch ($AppConfigType) {
    "ManagedAppConfig" { 
        $CreatedResult = New-MgDeviceAppManagementTargetedManagedAppConfiguration -BodyParameter $JSON_Output
        if ($null -ne $CreatedResult.id) {
            Write-Host "Policy created with id" $CreatedResult.Id
        }
        else {
            Write-Host "Policy creation failed" -ForegroundColor Red
        }
    }
    "ManagedDeviceAppConfig" {
        $CreatedResult = New-MgDeviceAppManagementMobileAppConfiguration -BodyParameter $JSON_Output
        if ($null -ne $CreatedResult.id) {
            Write-Host "Policy created with id" $CreatedResult.Id
        }
        else {
            Write-Host "Policy creation failed" -ForegroundColor Red
        }
    }
}