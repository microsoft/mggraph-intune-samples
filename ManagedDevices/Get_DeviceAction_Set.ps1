Import-Module Microsoft.Graph.DeviceManagement.Actions

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

Function Get-IntuneRemoteActions() {

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
		[Parameter(Mandatory = $false)]
		[string]$MgProfile
	)

	if ($MgProfile -ne "beta" -and $MgProfile -ne "v1.0") {
		$RemoteActions = Find-MgGraphCommand -Uri "deviceManagement/managedDevices/.*" -Method POST 

	}
	elseif ($MgProfile -eq "beta") {
		$RemoteActions = Find-MgGraphCommand -Uri "deviceManagement/managedDevices/.*" -Method POST -ApiVersion "beta"
	}
	elseif ($MgProfile -eq "v1.0") {
		$RemoteActions = Find-MgGraphCommand -Uri "deviceManagement/managedDevices/.*" -Method POST -ApiVersion "v1.0"
	}
	#Only show results with Module Name DeviceManagement.Actions
	$RemoteActions = Find-MgGraphCommand -Uri "deviceManagement/managedDevices/.*" -Method POST -ApiVersion $MgProfile
	Write-Host "Available Remote Actions:" -ForegroundColor Green
	
	$RemoteActions | Format-Table -Property Command, Uri, Method, ApiVersion 

	$SelectedCmdlet = Read-Host -Prompt "Enter the remote action Command name to view available parameters"
	Write-Host

	if ($SelectedCmdlet -notin $RemoteActions.Command) {
		Write-Host "Command not found. Exiting."
		exit
	}

 $Parameters = Get-Command -Name $SelectedCmdlet  | Select-Object -ExpandProperty Parameters
 $Parameters.Keys
 Write-Host
}
