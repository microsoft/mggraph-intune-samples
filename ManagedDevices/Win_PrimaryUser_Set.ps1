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

#Search for enrolled device by name
$DeviceName = Read-Host -Prompt "Enter the device name to search for"
$Devices = Get-MgDeviceManagementManagedDevice -Filter "DeviceName eq '$DeviceName'" | Select-Object  DeviceName, Id, userPrincipalName, UserId
if ($null -eq $Devices) {
    Write-Output "No devices found with the name $DeviceName" 
    return
}

$Devices | Format-Table -AutoSize
$DeviceId = Read-Host -Prompt "Enter the Intune Device ID (Id column) of the device id to set a new primary user for"

$UPN = Read-Host -Prompt "Enter the UPN of the user to set as the primary user for the selected device"
$User = Get-MgUser -Filter "UserPrincipalName eq '$UPN'" | Select-Object Id, UserPrincipalName, DisplayName
if ($null -eq $User) {
    Write-Output "No users found with the UPN $UPN" 
    return
}
#If for some reason more than one user is found, prompt for the UserId
#Otherwise, set the UserId to the Id of the user found
elseif ($User.Count -gt 1) {
    Write-Output "More than one user found with the UPN $UPN" 
    $User | Format-Table -AutoSize
    $UserId = Read-Host -Prompt "Confirm the UserId"
}
else {
    $UserId = $User.Id
}

#Build the body for Graph request
$Body = "{'@odata.id':'https://graph.microsoft.com/beta/users/$UserId'}"

#Build the URI for Graph request
$URI = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices('$DeviceId')/users/`$ref"

try {
    #Set primary user for device
    Invoke-MgGraphRequest -Method POST -Uri $URI -Body $Body
}
catch {
    Write-Output "$($_.Exception.Message)"
}

