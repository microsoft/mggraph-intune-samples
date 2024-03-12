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
$Devices = Get-MgDeviceManagementManagedDevice -Filter "DeviceName eq '$DeviceName'"

#Get the device details, primary user from Intune, and the registered owner and users from Azure AD
#Nesting loops in case multiple devices are returned, or multiple users are registered
foreach ($Device in $Devices) {
    $DeviceName = ($Device).DeviceName
    $IntuneDeviceId = ($Device).Id
    $UserId = ($Device).UserId
    $AzureAdDeviceId = ($Device).AzureAdDeviceId
    $AzureADObjectId = (Get-MgDevice -Filter "DeviceId eq '$AzureAdDeviceId'").Id
    $RegisteredOwnerId = (Get-MgDeviceRegisteredOwner -DeviceId $AzureADObjectId).Id
    $RegisteredUsersIds = (Get-MgDeviceRegisteredUser -DeviceId $AzureADObjectId).Id

    $RegisteredOwner = (Get-MgUser -UserId $RegisteredOwnerId).DisplayName  

    Write-Output "Device Name: $DeviceName"
    Write-Output  "Intune Device Id: $IntuneDeviceId"
    Write-Output  "Intune Primary user id: $UserId"

    Write-Output "AAD Registered Owner:"
    Write-Output  "Id: $RegisteredOwnerId"
    Write-Output  "Name: $RegisteredOwner"

    Write-Output "AAD Registered Users:"
    foreach ($ID in $RegisteredUsersIds) {
        $RegisteredUser = (Get-MgUser -UserId $ID).DisplayName  
        Write-Output "Id: $ID"
        Write-Output "Name: $RegisteredUser"
    }
}

