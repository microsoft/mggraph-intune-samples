Import-Module Microsoft.Graph.Reports

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

#Creating body for the report request. Example below is for the DeviceEncryption report
##For more information on creating the report request body, see https://learn.microsoft.com/en-us/mem/intune/fundamentals/reports-export-graph-apis
$ReportRequestBody =
'{
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
}'

####################################################    
# Function that is used to: 
# 1. Create the report export job 
# 2. Poll the service until it's ready
# 3. Download the .zip file 
# 4. Extract the .csv file
# 5. Convert the .csv file to a JSON object
# 6. Create a .json file
####################################################
function Invoke-ReportExportJob() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportRequestBody,
        [Parameter(Mandatory = $true)]
        [string]$ExportPath,
        [switch]$PreserveZip
    )

    #URI endpoint for report export jobs
    $URI = "https://graph.microsoft.com/v1.0/deviceManagement/reports/exportJobs"

    #POST request to create export job
    Write-Host "Creating report export job..."
    $Response = (Invoke-MgGraphRequest -Method POST -Uri $URI -Body $ReportRequestBody)
    #Check if the request was successful
    if ($?) {
        Write-Host "Report export job created successfully.`n"
    }
    else {
        Write-Error "`nUnable to create report export job. Please try again."
        break
    }

    #Storing report request ID to poll until it's been created
    $ReportId = $Response.id

    #Report URI to poll until it's ready for download
    $URI = "https://graph.microsoft.com/v1.0/deviceManagement/reports/exportJobs('$ReportId')"

    #Polling report download URI until it's ready for download
    do {
        Start-Sleep -Seconds 3
        $Response = (Invoke-MgGraphRequest -Method GET -Uri $URI)
        if ($?) {
            $ReportDownloadURL = $Response.url
            Write-Host "Report Status: $($Response.status)..."
        }
        else {
            #If the request fails, break out of the loop
            Write-Error "`nUnable to get report status. Please try again."
            break
        }
    } until ($Response.status -eq 'completed' -or $Response.status -eq 'failed')

    if ($Response.status -eq 'failed') {
        Write-Error "`nReport $ReportId failed to export. Please try again."
        break
    }
    #Report is ready for download
    elseif ($Response.status -eq 'completed') {
        #Downloading .zip containing .csv file
        $ZipPath = "$ExportPath\$ReportId.zip"
        Write-Host "`nDownloading report $ReportId to $ZipPath"
        Invoke-WebRequest -Uri $ReportDownloadURL -OutFile $ZipPath

        if (Test-Path $ZipPath) {
            Write-Host "$ReportId.zip downloaded successfully."
        }
        else {
            Write-Error "`nUnable to download report $ReportId. Please try again."
            break
        }

        #Extracting .csv file from .zip
        Write-Host "Extracting .csv file to $ExportPath"
        Expand-Archive -Path $ZipPath -DestinationPath $ExportPath -Force
        $Csv = "$ExportPath\$ReportId.csv"

        # If the user doesn't want to preserve the .zip file, delete it
        if (!$PreserveZip) {
            Write-Host "Cleaning up .zip file $ZipPath"
            Remove-Item $ZipPath -Force
        }

        #Importing data from report .csv 
        $ReportData = Import-Csv -Path $Csv
        #Storing as table for viewing in terminal if desired
        $Table = $ReportData | Format-Table -AutoSize
        #As JSON object
        $Json = $ReportData | ConvertTo-Json -Depth 100
        #Creating JSON file
        Write-Host "Creating .json file for report $ReportId"
        $Json | Out-File "$ExportPath\$ReportId.json" -Force

        #Check if the csv and json files have been created
        $CsvExists = Test-Path $Csv
        $JsonExists = Test-Path "$ExportPath\$ReportId.json"

        if ($CsvExists -eq $true -and $JsonExists -eq $true) {
            Write-Host "`nReport $ReportId has been downloaded and extracted to $ExportPath in .csv and .json formats."
            Write-Output 'Enter "$Json" or "$Table" to view the report in the terminal.'
        }
        else {
            Write-Error "`nUnable to find the report files in $ExportPath."
        }
    }
}
