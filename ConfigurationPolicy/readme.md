# Intune Configuration Policy script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

## Background

Configuration policies in Microsoft Intune use the `deviceManagement/configurationPolicies` endpoint and support various technology types beyond the traditional MDM (Mobile Device Management). These include:

- **mdm** - Traditional Mobile Device Management policies (Settings Catalog)
- **windows365** - Windows 365 Cloud PC policies
- **microsoftSense** - Microsoft Defender for Endpoint policies
- **endpointPrivilegeManagement** - Endpoint Privilege Management policies
- **configManager** - Configuration Manager policies
- **appleRemoteManagement** - Apple Remote Management policies
- And more...

Previously, these policies were classified under Settings Catalog. However, several policy types now have unique technology designations and require specialized handling for import/export operations that the standard Settings Catalog scripts don't support.

## Scripts in this Section

### 1. ConfigurationPolicy_Export.ps1
This script gets all configuration policies from the Intune Service that you have authenticated with, regardless of their technology type. The script will then export each policy to .json format in the directory of your choice.

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

#### Get-ConfigurationPolicy Function
This function is used to get all configuration policies from the Intune Service, supporting filtering by platform and/or technology type.

It supports optional parameters as input to filter the results:

```PowerShell
# Returns all Configuration policies configured in Intune
Get-ConfigurationPolicy

# Returns any Windows 10 Configuration policies configured in Intune
Get-ConfigurationPolicy -Platform windows10

# Returns any MacOS Configuration policies configured in Intune
Get-ConfigurationPolicy -Platform macOS

# Returns any Windows 365 Configuration policies configured in Intune
Get-ConfigurationPolicy -Technology windows365

# Returns any Microsoft Defender for Endpoint policies configured in Intune
Get-ConfigurationPolicy -Technology microsoftSense

# Returns any Endpoint Privilege Management policies configured in Intune
Get-ConfigurationPolicy -Technology endpointPrivilegeManagement
```

#### Get-ConfigurationPolicySettings Function
This function retrieves the settings for a specific configuration policy.

```PowerShell
Get-ConfigurationPolicySettings -policyid $policyid
```

#### Export-JSONData Function
This function is used to export the policy information. It has two required parameters -JSON and -ExportPath.

+ JSON - The JSON data
+ ExportPath - The path where the .json should be exported to

```PowerShell
Export-JSONData -JSON $JSON -ExportPath "$ExportPath"
```

### 2. ConfigurationPolicy_Import_FromJSON.ps1
This script imports a configuration policy from a JSON file that was previously exported using the ConfigurationPolicy_Export.ps1 script. It supports all technology types including Windows 365, Microsoft Defender for Endpoint, Endpoint Privilege Management, and traditional MDM policies.

The script will:
1. Read the JSON file
2. Validate the JSON format
3. Create the configuration policy with the specified name, description, platforms, and technologies
4. Add all settings from the exported policy to the newly created policy

```PowerShell
$ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"
```

#### Test-JSON Function
This function validates that the JSON being imported is valid.

```PowerShell
Test-JSON -JSON $JSON
```

#### Add-ConfigurationPolicy Function
This function creates a new configuration policy in Intune.

```PowerShell
Add-ConfigurationPolicy -JSON $JSON
```

#### Add-ConfigurationPolicySettings Function
This function adds settings to an existing configuration policy.

```PowerShell
Add-ConfigurationPolicySettings -JSON $JSON -policyid $policyid
```

## Usage Examples

### Exporting Policies

1. Connect to Microsoft Graph:
   ```PowerShell
   Connect-MgGraph -Scopes "DeviceManagementConfiguration.Read.All"
   ```

2. Run the export script:
   ```PowerShell
   .\ConfigurationPolicy_Export.ps1
   ```

3. Specify the export path when prompted (e.g., `C:\IntuneBackup`)

### Importing Policies

1. Connect to Microsoft Graph:
   ```PowerShell
   Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
   ```

2. Run the import script:
   ```PowerShell
   .\ConfigurationPolicy_Import_FromJSON.ps1
   ```

3. Specify the path to the JSON file when prompted (e.g., `C:\IntuneBackup\MyPolicy_01-01-2024-10-30-00.json`)

## Difference from Settings Catalog Scripts

The key difference between these Configuration Policy scripts and the Settings Catalog scripts is:

- **Settings Catalog scripts** filter for `technologies has 'mdm'` only
- **Configuration Policy scripts** support ALL technology types, including:
  - Windows 365 (`windows365`)
  - Microsoft Defender for Endpoint (`microsoftSense`)
  - Endpoint Privilege Management (`endpointPrivilegeManagement`)
  - And all other technology types

This makes the Configuration Policy scripts more comprehensive and suitable for modern Intune deployments that use multiple technology types beyond traditional MDM.
