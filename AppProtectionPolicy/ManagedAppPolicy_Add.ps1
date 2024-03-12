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

# Define the apps to be included in the policy
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

# Create the policy
$CreateResult = New-MgDeviceAppMgtiOSManagedAppProtection `
	-Apps $Apps `
	-AllowedDataStorageLocations oneDriveForBusiness `
	-AllowedInboundDataTransferSources allApps `
	-AllowedOutboundClipboardSharingLevel managedAppsWithPasteIn `
	-AllowedOutboundDataTransferDestinations allApps `
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

if ($null -ne $CreateResult.Id -and $CreateResult.Id -ne "") {
	# Confirm the policy was created successfully by printing the ID
	Write-Host "Policy created with id" $CreateResult.id
}
else {
	Write-Host "Policy creation failed" -ForegroundColor Red
}