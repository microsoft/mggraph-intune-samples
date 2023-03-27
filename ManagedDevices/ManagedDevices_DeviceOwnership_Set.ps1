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

# Uncomment the line below to return a list of all Intune managed devices
# Get-MgUserManagedDevice -All

Function Set-IntuneDeviceOwnerShip() {

    <#
	.SYNOPSIS
	This function is used to return available remote actions from the Graph PowerShell SDK
	.DESCRIPTION
	The function scans the installed Graph PowerShell SDK for available remote actions based on specified Graph version and asks the user for a remote action to return the parameters for
	.EXAMPLE
	Get-IntuneRemoteActions -MgProfile beta
	Returns all Graph PowerShell SDK remote actions for the specified Graph beta version

    Get-IntuneRemoteActions -MgProfile "v1.0"
	Returns all Graph PowerShell SDK remote actions for the specified Graph v1.0 version
	.NOTES
	NAME: Get-IntuneRemoteActions
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