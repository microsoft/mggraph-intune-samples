# Graph Permission Analyzer script sample

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. Permission_Analyzer.ps1
This script includes the `Get-ScriptPermissions` function, which reads a provided PowerShell script and searches for Graph SDK cmdlets within it. It then uses the `Find-MgGraphCommand` function to find the permissions required for each cmdlet and identifies the least-privileged permissions required for the script. The script outputs the script name, Graph cmdlets found, permissions, the least-privileged permissions required to run the script, if `Invoke-MgGraphRequest` was detected, and cmdlets that were not found.

1. First, run the script.
```PowerShell
.\Permission_Analyzer.ps1
```
2. Then, you can call the `Get-ScriptPermissions` function to analyze a script.
```PowerShell
Get-ScriptPermissions -ScriptPath ".\Win_PrimaryUser_Set.ps1"
```
Which will return the script name, detected cmdlets, their least-privileged permissions, if `Invoke-MgGraphRequest` was detected, and cmdlets that did not find permissions:
 ```PowerShell
 CmdletsNotFound            : {}
 ScriptName                 : Win_PrimaryUser_Set.ps1
 Invoke-MgGraphRequestFound : True
 LeastPrivilegedPermissions : {DeviceManagementManagedDevices.Read.All, User.ReadBasic.All}
 CmdletsDetected            : {Get-MgDeviceManagementManagedDevice, Get-MgUser}
 ```
 To analyze all scripts in a directory:
 ```PowerShell
 Get-ChildItem -Path "C:\mggraph-intune-samples" -Recurse -Filter *.ps1 | ForEach-Object {
  Get-ScriptPermissions -ScriptPath $_.FullName }
 ```

#### Note: This script does NOT check permissions for Graph calls manually made using Invoke-MgGraphRequest. You should manually review these calls to ensure they have the appropriate permissions.
   
