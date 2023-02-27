# Application Sync script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. Sync-AppleVPP.ps1
This script reads the Apple VPP tokens in your Intune tenant and synchronizes with the Apple VPP service. If there are multiple VPP tokens, you will be prompted to select which token you wish to synchronize. If there are no VPP tokens, the script does not take any action. If there is only one VPP token found, it will automatically issue a sync to that token. The script will not synchronize multiple tokens at once.

### 2. ManagedGooglePlay_Sync.ps1
This script queries the Managed Google Play configuration in your Intune tenant. If a configuration is found as 'boundAndValidated', it synchronizes approved applications from the Managed Google Play Store to Intune.
