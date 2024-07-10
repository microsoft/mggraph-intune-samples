Import-Module Microsoft.Graph.Beta.Devices.CorporateManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>


# Managed device app configuration policies (MDM channel)
$ManagedDeviceAppConfigPolicies = Get-MgBetaDeviceAppManagementMobileAppConfiguration -All -Property Id, DisplayName, Description
# Managed app app configuration policies (MAM channel)
$ManagedAppAppConfigPolicies = Get-MgBetaDeviceAppManagementTargetedManagedAppConfiguration -All -Property Id, DisplayName, Description

if (($ManagedDeviceAppConfigPolicies.Length -eq 0) -and ($ManagedAppAppConfigPolicies.Length -eq 0)) {
    Write-Host "No policies found" -ForegroundColor Red
    break
}

Write-Host 
Write-Host "Managed Device App Config Policies:"
$ManagedDeviceAppConfigPolicies | Format-Table -Property Id, DisplayName, Description

Write-Host 
Write-Host "Managed App App Config Policies:"
$ManagedAppAppConfigPolicies | Format-Table -Property Id, DisplayName, Description

Write-Host
$ExportPath = Read-Host -Prompt "Please specify a path to export each policy's JSON file to e.g. C:\IntuneOutput"

# If the directory path doesn't exist prompt user to create the directory
if (!(Test-Path "$ExportPath")) {
    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist, do you want to create this directory? Y or N?" -ForegroundColor Yellow

    $Confirm = Read-Host

    if ($Confirm -eq "y" -or $Confirm -eq "Y") {

        New-Item -ItemType Directory -Path "$ExportPath" | Out-Null
        Write-Host
    }
    else {
        Write-Host "Creation of directory path was cancelled..." -ForegroundColor Red
        Write-Host
        break
    }
}

Write-Host "Exporting policies..." -ForegroundColor Green
Write-Host
foreach ($Id in $ManagedDeviceAppConfigPolicies.Id) {
    try {
        #Example export using Get-MgDeviceAppManagementMobileAppConfiguration with JSON manipulation to add additionalProperties in the proper format for later import.
        $Policy = Get-MgDeviceAppManagementMobileAppConfiguration -ManagedDeviceMobileAppConfigurationId $Id | Select-Object  Id, displayName, targetedMobileApps, additionalProperties
        #Extract the properties within additionalProperties from the object and add them as a root properties 
        $AdditionalProperties = $Policy.AdditionalProperties
        $Policy | Add-Member -NotePropertyMembers $AdditionalProperties -Force 
        $PolicyToConvert = $Policy | Select-Object * -ExcludeProperty AdditionalProperties
        #Renaming properties to match the import format
        $PolicyToConvert | Add-Member -MemberType NoteProperty -Name "targetedMobileApps" -Value $Policy.TargetedMobileApps -Force
        $PolicyToConvert | Add-Member -MemberType NoteProperty -Name "displayName" -Value $Policy.DisplayName -Force
    }
    catch {
        $_.Exception.Message
    }
    $PolicyToConvert | ConvertTo-Json -Depth 10 | Out-File "$ExportPath\ManagedDeviceAppConfig_$($Policy.DisplayName)_$($Policy.Id).json"
    if ($? -eq $true) {
        Write-Host "JSON file created and can be found at $ExportPath\ManagedDeviceAppConfig_$($Policy.DisplayName)_$($Policy.Id).json" -ForegroundColor Green
    }
}

foreach ($Id in $ManagedAppAppConfigPolicies.Id) {
    try {
        #Example export using Invoke-MgGraphRequest without any manual JSON manipulation
        $Policy = Invoke-MgGraphRequest -Method GET -Uri ("https://graph.microsoft.com/v1.0/deviceAppManagement/targetedManagedAppConfigurations/$Id" + '?$expand=apps')
        $PolicyToConvert = $Policy
    }
    catch {
        $_.Exception.Message
    }

    $PolicyToConvert | ConvertTo-Json -Depth 5 | Out-File "$ExportPath\ManagedAppAppConfig_$($Policy.DisplayName)_$($Policy.Id).json"
    if ($? -eq $true) {
        Write-Host "JSON file created and can be found at $ExportPath\ManagedAppAppConfig_$($Policy.DisplayName)_$($Id).json" -ForegroundColor Green
    }
}
