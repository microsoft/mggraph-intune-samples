# Intune Apple Enrollment script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. APNS_Get.ps1
This script gets Apple Push Notification Certificate information from the Intune Service that you have authenticated with.

### 2. ADE_Sync.ps1
This script reads the Apple DEP tokens in your Intune tenant and synchronizes with the Apple DEP service. If there are multiple DEP tokens, you will be prompted to select which token you wish to synchronize. The script will not synchronize multiple tokens at once.

WARNING: The Apple DEP service only accepts a synchronization request once every 15 minutes. If you try and synchronize more often than this, the script will inform you that a synchronization is already in progress and will provide the time remaining before another synchronization can occur.

### 3. ADEProfile_Assign.ps1
This script assigns an ADE (DEP) profile to a device. If there are multiple DEP tokens, you will be prompted to select which token you wish to work with. You will then be prompted for a device serial number, and then presented with a list of ADE (DEP) profiles. The selected profile will then be assigned to the device.

### 4. ADEProfile_Assign_CSV.ps1
This script assigns an ADE (DEP) profile to a list of devices imported through a .csv file containing their serial numbers. If there are multiple DEP tokens, you will be prompted to select which token you wish to work with. You will then be presented with a list of ADE (DEP) profiles and prompted for the .csv file path containing the serial numbers of the devices to import. Upon confirmation, the selected profile will then be assigned to the devices. 

The script accepts .csv files in the following format:<br />

C39XDYM40000<br />
C39XDYM41111<br />
C39XDYM42222<br />
C39XDYM43333<br />
