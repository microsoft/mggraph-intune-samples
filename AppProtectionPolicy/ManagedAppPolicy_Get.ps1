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