# Intune Filters samples

This repository of PowerShell sample scripts show how to retrieve, create, and import Intune Filters using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. IntuneFilter_Get.ps1
This script gets all the Filters from the Intune Service that you have authenticated with.

### 2. IntuneFilter_Export.ps1
This script gets all Filters from the Intune Service that you have authenticated with. The script will then export the Filters to .json format in the directory of your choice.

For retrieving the filters the example uses the Get-MgBetaDeviceManagementAssignmentFilter cmdlet and manipulates property names/structure of the returned data into a more consumable JSON format for later imports.

### 3. IntuneFilter_Import_FromJSON.ps1
This script imports and creates a filter into the Intune Service that you have authenticated with from a specified JSON file.

When you run the script it will prompt for a path to a .json file, if the path and JSON are valid the import will be attempted.

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
