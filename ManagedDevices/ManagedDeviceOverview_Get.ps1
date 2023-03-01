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

Select-MgProfile -Name v1.0

# Using Invoke-MgGraphRequest instead of Get-MgDeviceManagementManagedDeviceOverview as it contains more OS information
$Overview = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDeviceOverview" -Method GET -ContentType "application/json" 

$OSCount = $Overview.deviceOperatingSystemSummary

Write-Output ("Total: " + $Overview.mdmEnrolledCount)
Write-Output $OSCount
