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

Select-MgProfile -Name "v1.0"

#Retrieve all managed devices
Get-MgDeviceManagementManagedDevice -All


# Retrieve all managed devices by operating system:
<# 
Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'Android'"
Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'iOS'"
Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'macOS'"
Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'Windows'"
Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'Chrome OS'"
Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'WindowsMobile'" 
#>

#Retrieve all managed devices by UPN of primary user
# Get-MgDeviceManagementManagedDevice -Filter "userPrincipalName eq '$UPN'"

#Retrieve associated user of a managed device by device ID
# Get-MgDeviceManagementManagedDeviceUser -DeviceId $DeviceId
