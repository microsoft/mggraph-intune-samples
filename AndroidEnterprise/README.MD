# Intune Android Enterprise script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. Get-AndroidDeviceOwnerProfiles.ps1
This script gets any Android Enterprise Device Owner Enrollment Profiles from the Intune Service that you have authenticated with.

### 2. Get-AndroidDedicatedDeviceQRCode.ps1
This script retrieves the QR code image from a given Dedicated Device Enrollment Profile, and saves it to a specified location. If there are multiple enrollment profiles, you will be prompted to select which one to work with.

The script will show the following warning before export.
```
- You are about to export the QR code for the Dedicated Device Enrollment Profile 'Profile Name'
- Anyone with this QR code can Enrol a device into your tenant. Please ensure it is kept secure.
- If you accidentally share the QR code, you can immediately expire it in the Intune UI.
- Devices already enrolled will be unaffected.
```
### 3. Get-AndroidWorkProfileConfiguration.ps1
This script queries the Intune Service and returns Enrollment Restriction configurations that impact Android Enterprise. If a configuration is found it will list the AAD Groups assigned to it (with the exception of the Default tenant enrollment profile, which is always assigned to All Users).
