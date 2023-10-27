# Intune Settings Catalog  Policy script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.


### 1. SettingsCatalog_Export.ps1
This script gets all the settings catalog policies from the Intune Service that you have authenticated with. The script will then export the policy to .json format in the directory of your choice.

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
This function is used to get all settings catalog policies from the Intune Service.

It supports a single parameters as an input to the function to pull data from the service.

```PowerShell
# Returns any Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy

# Returns any Windows 10 Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform windows10

# Returns any MacOS Settings Catalog policies configured in Intune
Get-SettingsCatalogPolicy -Platform macOS

```

#### Export-JSONData Function
This function is used to export the policy information. It has two required parameters -JSON and -ExportPath.

+ JSON - The JSON data
+ ExportPath - The path where the .json should be exported to

```PowerShell
Export-JSONData -JSON $JSON -ExportPath "$ExportPath"
```
