# Intune App Protection Policy script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. ManagedAppPolicy_Add.ps1
This script adds an example iOS App Protection policy into the Intune Service that you have authenticated with. The script performs the functions below:
1. Create an array of mobile app identifiers for Microsoft Office and Microsoft Outlook ($Apps).
2. Defines the App Protection Policy using New-MgDeviceAppMgtiOSManagedAppProtection with the following parameters:
```PowerShell
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
-PeriodOnlineBeforeAccessCheck 30
```
4. Confirms that the policy was created successfully and prints the policy's ID.

### 2. ManagedAppPolicy_Add_Assign.ps1
This script adds an example iOS App Protection policy into the Intune Service that you have authenticated with and assigns it to a specified Azure AD group. The script performs the functions below:
1. Prompts the administrator to select an Azure AD group to assign the policy to.
2. Creates an array of mobile app identifiers for Microsoft Office and Microsoft Outlook ($Apps).
3. Defines the App Protection Policy using New-MgDeviceAppMgtiOSManagedAppProtection with the following arguments:

```PowerShell
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
```
4. Confirms that the policy was created successfully and prints the policy's ID.

### 3. ManagedAppPolicy_Get.ps1
This script gets all the App Protection policies from the Intune Service that you have authenticated with.

### 4. ManagedAppPolicy_MobileAppIdentifier_Get.ps1
This script gets all the App Protection policy Managed Applications from the Intune Service that you have authenticated with.

### 5. ManagedAppPolicy_Remove.ps1
This script gets all the App Protection policies from the Intune Service that you have authenticated with, then:
1. Prompts the administrator to specify a policy to delete by policy ID.
2. Removes/deletes the policy from the service.

### 6. ManagedAppPolicy_Wipe.ps1
This script wipes a specified user's application data where an App Protection policy has been applied. It performs the following actions:
1. Prompts the administrator to enter the user's UPN to perform an application wipe on.
2. Prompts the administrator to choose if they want to wipe ALL managed apps on ALL of the user's devices, or ALL managed apps on one device specified by DeviceTag.
3. Prompts the administrator to confirm wipe of the application data.

### 7. ManagedAppPolicy_Export.ps1
This script gets all App Protection policies (Android and iOS) from the Intune Service that you have authenticated with. The script will then export the policies to .json format in the directory of your choice.

### 8. ManagedAppPolicy_Import_FromJSON.ps1
This script imports and creates an App Protection Policy into the Intune Service that you have authenticated with from a specified JSON file.

When you run the script it will prompt for a path to a .json file, if the path and JSON are valid the import will be executed.

```PowerShell
$ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"

# Replacing quotes for Test-Path
$ImportPath = $ImportPath.replace('"','')

if(!(Test-Path "$ImportPath")){

Write-Host "Import Path for JSON file doesn't exist..." -ForegroundColor Red
Write-Host "Script can't continue..." -ForegroundColor Red
Write-Host
break

}
```
