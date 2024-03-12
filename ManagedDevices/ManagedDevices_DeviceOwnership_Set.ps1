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

# Uncomment the line below to return a list of all Intune managed devices
# Get-MgUserManagedDevice -All

Function Set-IntuneDeviceOwnership() {

    <#
	.SYNOPSIS
	This function is used to set the device ownership property for a specified Intune managed device
	.DESCRIPTION
	The function calls the Update-MgDeviceManagementManagedDevice cmdlet to set the device ownership property for a specified Intune managed device
	.EXAMPLE
    Set-IntuneDeviceOwnership -ManagedDeviceId $ManagedDeviceId -ManagedDeviceOwnerType $ManagedDeviceOwnerType

	.NOTES
	NAME: Set-IntuneDeviceOwnership
	#>
	
    [cmdletbinding()]
	
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceId,
        [Parameter(Mandatory = $true)]
        [string]$ManagedDeviceOwnerType
    )

    Update-MgDeviceManagementManagedDevice -ManagedDeviceId $ManagedDeviceId -ManagedDeviceOwnerType $ManagedDeviceOwnerType
}