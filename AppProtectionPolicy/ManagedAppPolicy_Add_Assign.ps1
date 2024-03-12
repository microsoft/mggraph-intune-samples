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

# Set the AAD Group where the policy will be assigned
$AADGroup = Read-Host -Prompt "Enter the Azure AD Group name where policies will be assigned"
$SelectedGroup = (Get-MgGroup -Filter "DisplayName eq '$AADGroup'")

#if there is more than one group returned, prompt user to select the correct group
if ($SelectedGroup.Count -gt 1) {
	Write-Host
	Write-Host "There are multiple groups with the name '$AADGroup', please select the correct group from the list below:" -ForegroundColor Yellow
	Write-Host
	$SelectedGroup | Format-Table -Property DisplayName, Id
	Write-Host
	$SelectedGroup = Read-Host -Prompt "Enter the Group ID from the list above"
}
elseif ($SelectedGroup.Count -eq 1) {
	$TargetGroupId = $SelectedGroup.Id
}

if ($null -eq $TargetGroupId -or $TargetGroupId -eq "") {
	Write-Host "AAD Group - '$AADGroup' doesn't exist, please specify a valid AAD Group..." -ForegroundColor Red
	Write-Host
	exit
}

#Create a hash table for the assignment including the AAD Group ID
$assignments = @(
	@{
		target = @{
			groupId       = $TargetGroupId
			"@odata.type" = "#microsoft.graph.groupAssignmentTarget"
		}
	}
)

#Create a hash table for the apps to be included in the policy
$Apps = @(
	@{
		MobileAppIdentifier = @{
			"@odata.type" = "#microsoft.graph.iosMobileAppIdentifier"
			bundleId      = "com.microsoft.officemobile"
		}
	}
	@{
		MobileAppIdentifier = @{
			"@odata.type" = "#microsoft.graph.iosMobileAppIdentifier"
			bundleId      = "com.microsoft.office.outlook"
		}
	}
)

Write-Host "Creating Policy..."
Write-Host

#Create the policy
$CreateResult = New-MgDeviceAppMgtiOSManagedAppProtection `
	-Apps $Apps `
	-AllowedDataStorageLocations oneDriveForBusiness `
	-AllowedInboundDataTransferSources allApps `
	-AllowedOutboundClipboardSharingLevel managedAppsWithPasteIn `
	-AllowedOutboundDataTransferDestinations allApps `
	-Assignments $assignments `
	-ContactSyncBlocked `
	-DataBackupBlocked `
	-DeviceComplianceRequired `
	-DisableAppPinIfDevicePinIsSet `
	-FaceIdBlocked `
	-FingerprintBlocked `
	-DisplayName 'iOS App Protection Policy' `
	-ManagedBrowser microsoftEdge `
	-OrganizationalCredentialsRequired `
	-MinimumWarningOSVersion 12.0 `
	-PeriodBeforePinReset 30 `
	-SaveAsBlocked `
	-PrintBlocked `
	-PinRequired `
	-PeriodOfflineBeforeAccessCheck 720 `
	-PeriodOfflineBeforeWipeIsEnforced 90 `
	-PeriodOnlineBeforeAccessCheck 30 `

#Display confirmation
if ($null -ne $CreateResult.Id -and $CreateResult.Id -ne "") {
	Write-Host "Policy created with id" $CreateResult.id
	Write-Host "Assigned $($CreateResult.displayName)/$($CreateResult.id) to $AADGroup"
}
else {
	Write-Host "Policy creation failed" -ForegroundColor Red
}


