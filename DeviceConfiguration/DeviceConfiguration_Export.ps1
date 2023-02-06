Import-Module Microsoft.Graph.DeviceManagement

####################################################

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
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
#endregion

####################################################

$ExportPath = Read-Host -Prompt "Please specify a path to export the policy data to e.g. C:\IntuneOutput"

# If the directory path doesn't exist prompt user to create the directory
$ExportPath = $ExportPath.replace('"', '')

if (!(Test-Path "$ExportPath")) {

    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist, do you want to create this directory? Y or N?" -ForegroundColor Yellow

    $Confirm = read-host

    if ($Confirm -eq "y" -or $Confirm -eq "Y") {

        new-item -ItemType Directory -Path "$ExportPath" | Out-Null
        Write-Host

    }

    else {

        Write-Host "Creation of directory path was cancelled..." -ForegroundColor Red
        Write-Host
        break

    }

}

####################################################

Write-Host

# Filtering out iOS and Windows Software Update Policies
$DCPs = Get-MgDeviceManagementDeviceConfiguration | Select-Object Id, DisplayName, Version, AdditionalProperties | Where-Object { ($_.AdditionalProperties.'@odata.type' -ne "#microsoft.graph.iosUpdateConfiguration") -and ($_.AdditionalProperties.'@odata.type' -ne "#microsoft.graph.windowsUpdateForBusinessConfiguration") }

foreach ($DCP in $DCPs) {
    $fName = $DCP.displayName
    write-host "Device Configuration Policy:"$fName -f Yellow
    $DCP | ConvertTo-Json -Depth 100 | Out-File -FilePath "$ExportPath\$fName.json" -Encoding UTF8
    Write-Host
}