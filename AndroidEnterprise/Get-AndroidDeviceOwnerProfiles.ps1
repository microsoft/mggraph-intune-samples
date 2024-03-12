Import-Module Microsoft.Graph.Beta.DeviceManagement.Enrollment

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Get all Android device profiles
Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile | Format-Table -AutoSize

# Get all Android dedicated device profiles
#Get-MgDeviceManagementAndroidDeviceOwnerEnrollmentProfile -Filter "EnrollmentMode eq 'corporateOwnedDedicatedDevice'" | Format-Table -AutoSize

# Get all Android corporate owned work profile profiles
#Get-MgDeviceManagementAndroidDeviceOwnerEnrollmentProfile -Filter "EnrollmentMode eq 'corporateOwnedWorkProfile'" | Format-Table -AutoSize