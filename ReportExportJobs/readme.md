# Intune Reporting Export API script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. Report_ExportJob.ps1
This script performs the following actions against the Intune service that you have authenticated with:

1. Creates a report export job in the Intune service using the top-level export API. (https://learn.microsoft.com/en-us/mem/intune/fundamentals/reports-export-graph-apis?source=recommendations)
2. Polls the service until the export job has completed, and the .zip file containing the report in .csv format is ready for download.
3. Downloads the .zip file to specified path.
4. Extracts the .csv report file.
6. Creates a .json file from the .csv data.
7. Optionally, deletes the downloaded .zip folder, leaving both the .csv and .json report files.

By default, the script generates the DeviceEncryption report using the following request:

```JSON
{
    "reportName": "DeviceEncryption",
    "filter": "",
    "select": [
        "DeviceId",
        "DeviceName",
        "DeviceType",
        "OSVersion",
        "TpmSpecificationVersion",
        "EncryptionReadinessState",
        "EncryptionStatus",
        "UPN",
        "SettingStateSummary",
        "AdvancedBitlockerState",
        "PolicyDetails"
    ],
    "format": "csv",
    "localizationType": "ReplaceLocalizableValues"
}
```

The request body can be modified as needed by updating the $ReportRequestBody variable. This allows you to generate other reports that have migrated to the Intune reporting infrastructure. For more information on crafting the report request body, see https://learn.microsoft.com/en-us/mem/intune/fundamentals/reports-export-graph-apis

### Running the script
1. Run the script in an IDE such as VS Code.

####
```PowerShell
.\Report_ExportJob.ps1
```

```PowerShell
#To keep the zip, json, and csv files:
Invoke-ReportExportJob -ReportRequestBody $ReportRequestBody -ExportPath C:\IntuneOutput -PreserveZip
```

```PowerShell
#To delete the zip file, and keep the json and csv files:
Invoke-ReportExportJob -ReportRequestBody $ReportRequestBody -ExportPath C:\IntuneOutput
```

```PowerShell
#To display the report in json format in the terminal after it has been succesfully generated:
$Json
```

```PowerShell
#To display the report in table format in the terminal after it has been succesfully generated:
$Table
```
