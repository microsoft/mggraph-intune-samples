# Intune Settings Catalog  Policy script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.


### 1. SettingsCatalog_Export.ps1
This script gets all the settings catalog policies from the Intune Service that you have authenticated with. The script will then export the policy to .json format in the directory of your choice.

In addition to settings catalog policies, the script also exports two policy types that previously appeared under the Settings Catalog but now live on their own endpoints:

+ Resource access profiles (`deviceManagement/resourceAccessProfiles`)
+ Hardware configurations (`deviceManagement/hardwareConfigurations`)

These use a different schema to settings catalog policies, so they are exported as complete objects and re-created by the matching import script.

```PowerShell
$ExportPath = Read-Host -Prompt "Please specify a path to export the policy data to e.g. C:\IntuneOutput"

    # If the directory path doesn't exist prompt user to create the directory

    if(!(Test-Path "$ExportPath")){

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist, do you want to create this directory? Y or N?" -ForegroundColor Yellow

    $Confirm = read-host

        if($Confirm -eq "y" -or $Confirm -eq "Y"){

        new-item -ItemType Directory -Path "$ExportPath" | Out-Null
        Write-Host

        }

        else {

        Write-Host "Creation of directory path was cancelled..." -ForegroundColor Red
        Write-Host
        break

        }

    }
```

#### Get-SettingsCatalogPolicy Function
This function is used to get all settings catalog policies from the Intune Service. It follows the `@odata.nextLink` paging so every policy is returned, not just the first page, and is scoped to MDM technology policies.

It supports an optional `-Platform` parameter to scope the results to a single platform. Supported values are `windows10`, `windows10X`, `macOS`, `iOS`, `android`, `androidEnterprise`, `aosp`, `linux`, `visionOS`, and `tvOS`.

> **Note on the `technologies` filter:** the function filters on `technologies has 'mdm'`, which covers the most common settings catalog policies. Other technologies are also backed by the same `configurationPolicies` endpoint — for example `endpointPrivilegeManagement` (EPM), `enrollment` (Autopilot device preparation), `windowsOsRecovery`, `exchangeOnline`, and `microsoftSense`. If you need to export those, change or remove the `technologies has 'mdm'` filter in the function (e.g. `technologies has 'endpointPrivilegeManagement'`, or drop the filter entirely to return every configuration policy regardless of technology).

```PowerShell
# Returns any Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy

# Returns any Windows 10 Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform windows10

# Returns any macOS Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform macOS

# Returns any iOS/iPadOS Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform iOS

```

#### Get-IntuneResourceCollection and Get-IntuneResourceObject Functions
These functions retrieve the additional policy types that branched out of the Settings Catalog (resource access profiles and hardware configurations). `Get-IntuneResourceCollection` returns all items from a collection endpoint, following `@odata.nextLink` paging, and `Get-IntuneResourceObject` re-fetches a single object by id so all of its properties are returned for export.

```PowerShell
# Returns all resource access profiles configured in Intune
Get-IntuneResourceCollection -Resource "deviceManagement/resourceAccessProfiles"

# Returns a single hardware configuration by id
Get-IntuneResourceObject -Resource "deviceManagement/hardwareConfigurations" -Id $id
```

#### Export-JSONData Function
This function is used to export the policy information. It has two required parameters -JSON and -ExportPath.

+ JSON - The JSON data
+ ExportPath - The path where the .json should be exported to

```PowerShell
Export-JSONData -JSON $JSON -ExportPath "$ExportPath"
```

### 2. SettingsCatalog_Import_FromJSON.ps1
This script imports a policy from a .json file (such as one produced by SettingsCatalog_Export.ps1) back into the Intune Service. It handles settings catalog policies as well as the additional policy types that branched out of the Settings Catalog (resource access profiles and hardware configurations).

The script prompts for the path to a single .json file, validates that the file exists and contains valid JSON, determines which endpoint the policy should be created on, removes read-only properties, and creates the policy in Intune.

```PowerShell
$ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\policy.json"
```

#### Get-TargetResource Function
This function determines which Graph endpoint a policy JSON object should be imported to, based on the shape of the object:

+ Settings catalog policies (a `settings` collection / `technologies` value) are created on `deviceManagement/configurationPolicies`
+ Hardware configurations (a `configurationFileContent` / `hardwareConfigurationFormat` value) are created on `deviceManagement/hardwareConfigurations`
+ Resource access profiles (an `@odata.type` discriminator) are created on `deviceManagement/resourceAccessProfiles`

#### Set-ODataTypePrefix Function
This function ensures every `@odata.type` value is prefixed with `#`, which Graph requires for the OData type discriminator. It normalises the top-level type and any nested types so the file imports whether or not the `#` was present.
