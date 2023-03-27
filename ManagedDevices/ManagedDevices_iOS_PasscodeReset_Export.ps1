Import-Module Microsoft.Graph.DeviceManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

Select-MgProfile -Name v1.0

#URI endpoint for report export jobs
$URI = "https://graph.microsoft.com/v1.0/deviceManagement/reports/exportJobs"

#"filter": "((DeviceType eq "9") or (DeviceType eq "8") or (DeviceType eq "10") or (DeviceType eq "14"))",

#Creating body for request (report name and columns)
$Body = @{
    reportName = 'Devices'
    select     = @('DeviceId', "DeviceName", "OSVersion", "HasUnlockToken")
    filter     = "((DeviceType eq '14') or (DeviceType eq '9') or (DeviceType eq '8') or (DeviceType eq '10'))"
}

#POST request to create export job
$Response = (Invoke-MgGraphRequest -Method POST -Uri $URI -Body $Body)

#Storing report request ID to poll until it's been created
$ReportId = $Response.id

#Request time stamp
$RequestDateTime = $Response.requestDateTime 
$RequestDate = $RequestDateTime | Get-Date -Format "MM-dd-yyyy.HH-mm"

#Storing report readiness state
$ReportReady = $Response.status

#Report download URI
$URI = "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$ReportId')"

#Polling report download URI until it's ready for download
While ($ReportReady -ne 'completed') {
    $Response = (Invoke-MgGraphRequest -Method GET -Uri $URI)
    $ReportReady = $Response.status
    $ReportDownloadURL = $Response.url
    Start-Sleep -Seconds 3
}

$DownloadPath = Read-Host -Prompt "Enter full path to download and store the .zip, .csv, and .json files"

#Downloading .zip and extracting report .csv
$ZipPath = "$DownloadPath\$RequestDate.zip"
Invoke-WebRequest -Uri $ReportDownloadURL -OutFile $ZipPath 
$csv = Expand-Archive -Path $ZipPath -DestinationPath $DownloadPath -PassThru -Force
Rename-Item -Path $csv.FullName -NewName "$RequestDate.csv" -PassThru -Force

#Importing/exporting data from report .csv 
$data = Import-Csv "$DownloadPath\$RequestDate.csv"

#As JSON file
$JSON = $data | ConvertTo-Json -Depth 10
$JSON | Out-File "$DownloadPath\$RequestDate.json" -Force
Write-Output "`nThe report has been generated in .json and .csv format and can be found at: `n $DownloadPath\$RequestDate.csv `n $DownloadPath\$RequestDate.json `n"

