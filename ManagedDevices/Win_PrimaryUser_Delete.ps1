Import-Module Microsoft.Graph.DeviceManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

$DeviceName = Read-Host -Prompt "Enter the device name to search for"
$Devices = Get-MgDeviceManagementManagedDevice -Filter "DeviceName eq '$DeviceName'" | Select-Object  DeviceName, Id, userPrincipalName, UserId
if ($null -eq $Devices) {
    Write-Output "No devices found with the name $DeviceName" 
    return
}

#List the users devices
$Devices | Format-Table -AutoSize
$DeviceId = Read-Host -Prompt "Enter the Intune Device ID (Id column) of the device id to remove the primary user from"


#Build the URI for Graph request
$URI = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices('$DeviceId')/users/`$ref"

#Remove the primary user
try {
    Invoke-MgGraphRequest -Method DELETE -Uri $URI
}
catch {
    Write-Output "$($_.Exception.Message)"
}