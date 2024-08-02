Import-Module Microsoft.Graph.Reports
Import-Module Microsoft.Graph.Groups

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>


<#
.SYNOPSIS
Invokes an Intune report export job, downloads the report, and extracts the .csv file.

.PARAMETER ReportRequestBody
The body of the report request.
For more information on creating the report request body, see https://learn.microsoft.com/en-us/mem/intune/fundamentals/reports-export-graph-apis

.PARAMETER ExportPath
The path to save the exported report.

.EXAMPLE
Get-IntuneUsersWithManagedDevices -ReportRequestBody $ReportRequestBody -ExportPath "C:\Temp"
#>
function Get-IntuneUsersWithManagedDevices() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    #Creating body for the report request.
    ## 2: Intune MDM, 64: googleCloudDevicePolicyController
    $ReportRequestBody =
    '{
    "reportName":"DevicesWithInventory",
    "filter":"((ManagementAgents eq ''2'') or (ManagementAgents eq ''512'') or (ManagementAgents eq ''514'') or (ManagementAgents eq ''64''))",
    "select":["UPN"],
    "format": "csv",
    }'

    #URI endpoint for report export jobs
    $URI = "https://graph.microsoft.com/v1.0/deviceManagement/reports/exportJobs"

    #POST request to create export job
    Write-Host "Creating report export job..."
    $Response = (Invoke-MgGraphRequest -Method POST -Uri $URI -Body $ReportRequestBody)

    #Check if the request was successful
    if ($?) {
        Write-Host "Report export job created successfully."
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
            Write-Host "`n$ReportId.zip downloaded successfully."
        }
        else {
            Write-Error "`nUnable to download report $ReportId. Please try again."
            break
        }

        #Extracting .csv file from .zip
        Write-Host "`nExtracting .csv file to $ExportPath"
        Expand-Archive -Path $ZipPath -DestinationPath $ExportPath -Force
        $Csv = "$ExportPath\$ReportId.csv"

        Write-Host "`nCleaning up .zip file $ZipPath"
        Remove-Item $ZipPath -Force

        # Import the CSV file 
        $members = Import-Csv -Path $Csv

        #Remove the CSV file
        Write-Host "Cleaning up .csv file $Csv`n"
        Remove-Item $Csv -Force

        #Remove duplicate entries
        $members = $members | Sort-Object -Property 'Primary user UPN' -Unique

        return $members
    }
}

<#
.SYNOPSIS
Adds members to a group.

.PARAMETER members
Array of members to add to the group.

.PARAMETER groupId
String ID of the group to add members to.

.EXAMPLE
Add-MembersToGroup -members $members -groupId $groupId
#>
function Add-MembersToGroup() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [array]$members,
        [Parameter(Mandatory = $true)]
        [string]$groupId
    )

    # Get the current members of the group
    $groupMember = Get-MgGroupMember -GroupId $groupId -All

    # Iterate over each member and add them to the group 
    foreach ($member in $members){ 
        try {
            $DirectoryObjectId = (Get-MgUser -Filter "UserPrincipalName eq '$($member.'Primary user UPN')'").Id 

            #Check if the user is already a member of the group
            if ($DirectoryObjectId -in $groupMember.Id) {
                Write-Host "$($member.'Primary user UPN') is already a member of the group. Skipping..."
                continue
            }
            else {
                New-MgGroupMember -GroupId $groupId -DirectoryObjectId $DirectoryObjectId 
                Write-Host "Added '$($member.'Primary user UPN')' to group $groupId."             
            }
        } 
        Catch { 
            Write-Host "Error adding member $($member.memberObjectId):$($_.Exception.Message)" 
        } 
    }
}

<#
.EXAMPLE
$groupId = "39c1918e-1235-4835-9a20-1f8340193876"

#Export the report and get the members
$members = Get-IntuneUsersWithManagedDevices -ExportPath "C:\Temp"

#Add the members to the group
Add-MembersToGroup -members $members -groupId $groupId
#>