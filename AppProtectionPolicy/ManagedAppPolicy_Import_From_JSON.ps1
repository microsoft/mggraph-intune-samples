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

$ImportPath = Read-Host -Prompt "Please specify a path to a Json file to import data from e.g. C:\IntuneOutput\Policies\policy.Json"

# Replacing quotes for Test-Path
$ImportPath = $ImportPath.replace('"', '')

# Check if the path exists
if (!(Test-Path "$ImportPath")) {
    Write-Host "Import Path for Json file doesn't exist..." -ForegroundColor Red
    Write-Host "Script can't continue..." -ForegroundColor Red
    Write-Host
    break
}

#function to test if the Json is valid
Function Test-Json() {

    <#
    .SYNOPSIS
    This function is used to test if the Json passed to a REST Post request is valid
    .DESCRIPTION
    The function tests if the Json passed to the REST Post is valid
    .EXAMPLE
    Test-Json -Json $Json
    Test if the Json is valid before calling the Graph REST interface
    .NOTES
    NAME: Test-Json
    #>
    
    param ( 
        $Json  
    )
    
    try {
        ConvertFrom-Json $Json -ErrorAction Stop
    }
    catch {
        Write-Host "Provided Json isn't in valid Json format" -f Red
        $_.Exception
        break
    }
}

$Json_Data = Get-Content $ImportPath

# Excluding entries that are not required - id,createdDateTime,lastModifiedDateTime,version
$Json_Converted = $Json_Data | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty id, createdDateTime, lastModifiedDateTime, version, deployedAppCount

#If the appGroupType is selectedPublicApps, include the apps property
#If the appGroupType is not selectedPublicApps, exclude the apps property as the service will populate it
if ($Json_Converted.appGroupType -ne 'selectedPublicApps') {
    $Json_Converted = $Json_Data | ConvertFrom-Json | Select-Object -Property * -ExcludeProperty apps
}

$DisplayName = $Json_Converted.displayName
$Json_Output = $Json_Converted | ConvertTo-Json -Depth 5

Test-Json -Json $Json_Output
            
Write-Host "App Protection Policy '$DisplayName' Found..." -ForegroundColor Cyan
Write-Host "Importing Policy..." -ForegroundColor Yellow

try {
    #Check if the policy is for iOS or Android and create the policy accordingly
    if ($Json_Converted.'@odata.context'.StartsWith('https://graph.microsoft.com/beta/$metadata#deviceAppManagement/iosManagedAppProtections')) {
        $CreateResult = New-MgDeviceAppMgtiOSManagedAppProtection -BodyParameter $Json_Output
    }
    elseif ($Json_Converted.'@odata.context'.StartsWith('https://graph.microsoft.com/beta/$metadata#deviceAppManagement/androidManagedAppProtections')) {
        $CreateResult = New-MgDeviceAppMgtAndroidManagedAppProtection -BodyParameter $Json_Output
    }

    Write-Host "Policy created with id" $CreateResult.id -ForegroundColor Green

}
catch {
    Write-Host "Error creating policy" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    break
}