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

#Using get-mgdeviceappmanagementandroid/iosmanagedappprotection rather than get-mgdeviceappmanagementmanagedapppolicy to filter out app configuration policies
$androidPolicies = Get-MgDeviceAppManagementAndroidManagedAppProtection -Property Id
$iosPolicies = Get-MgDeviceAppManagementiOSManagedAppProtection  -Property Id

$AndroidApps = @()
$iOSApps = @()

foreach ($Policy in $androidPolicies.Id) {
    #if the app is not already in the list, add it
    $AndroidApps += Get-MgDeviceAppManagementAndroidManagedAppProtectionApp -AndroidManagedAppProtectionId $Policy | Where-Object { $AndroidApps -notcontains $_ }
}

foreach ($Policy in $iosPolicies.Id) {
    #if the app is not already in the list, add it
    $iOSApps += Get-MgDeviceAppManagementiOSManagedAppProtectionApp -IosManagedAppProtectionId $Policy | Where-Object { $iOSApps -notcontains $_ }
}

if ($AndroidApps.Length -eq 0 -and $iOSApps.Length -eq 0) {
    Write-Host "No apps found" -ForegroundColor Red
    break
}

Write-Host "Android Managed Apps:"
$AndroidApps | Format-Table -Property Id, Version
Write-Host
Write-Host "iOS Apps:"
$iOSApps | Format-Table -Property Id, Version
