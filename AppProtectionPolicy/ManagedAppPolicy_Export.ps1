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

# Using get-mgdeviceappmanagementandroid/iosmanagedappprotection rather than get-mgdeviceappmanagementmanagedapppolicy to filter out app configuration policies
$AndroidPolicies = Get-MgDeviceAppManagementAndroidManagedAppProtection -Property Id, DisplayName, Description
$iOSPolicies = Get-MgDeviceAppManagementiOSManagedAppProtection -Property Id, DisplayName, Description

if ($AndroidPolicies.Length -eq 0 -and $iOSPolicies.Length -eq 0) {
    Write-Host "No policies found" -ForegroundColor Red
    break
}

Write-Host 
Write-Host "Android Policies:"
$AndroidPolicies | Format-Table -Property Id, DisplayName, Description
Write-Host "iOS Policies:"
$iOSPolicies | Format-Table -Property Id, DisplayName, Description

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

#Loop through each Android policy and export the JSON file
Write-Host "Exporting Android policies..." -ForegroundColor Green
Write-Host
foreach ($Policy in $AndroidPolicies.Id) {
    try {
        $Policy = Get-MgDeviceAppManagementAndroidManagedAppProtection -AndroidManagedAppProtectionId $Policy
    }
    catch {
        Write-Host "An error occurred while retrieving the Managed App Policy with the id '$Id', please provide a valid policy id..." -f Red
        break
    }
    $Policy | ConvertTo-Json -Depth 10 | Out-File "$ExportPath\ManagedAppPolicy_$($Policy.DisplayName)_$($Policy.Id).json"
    if ($? -eq $true) {
        Write-Host "JSON file created and can be found at $ExportPath\ManagedAppPolicy_$($Policy.DisplayName)_$($Policy.Id).json" -ForegroundColor Green
    }
}

Write-Host
Write-Host "Exporting iOS policies..." -ForegroundColor Green
Write-Host

#Loop through each iOS policy and export the JSON file
foreach ($Policy in $iOSPolicies.Id) {
    try {
        $Policy = Get-MgDeviceAppManagementiOSManagedAppProtection -IosManagedAppProtectionId $Policy
    }
    catch {
        Write-Host "An error occurred while retrieving the Managed App Policy with the id '$Id', please provide a valid policy id..." -f Red
        Write-Host
        break
    }
    $Policy | ConvertTo-Json -Depth 10 | Out-File "$ExportPath\ManagedAppPolicy_$($Policy.DisplayName)_$($Policy.Id).json"
    if ($? -eq $true) {
        Write-Host "JSON file created and can be found at $ExportPath\ManagedAppPolicy_$($Policy.DisplayName)_$($Policy.Id).json" -ForegroundColor Green
    }
}