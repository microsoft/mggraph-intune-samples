Import-Module Microsoft.Graph.Devices.CorporateManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Using get-mgdevicemanagementdevicecompliancepolicy
$DCPs = Get-MgDeviceManagementDeviceCompliancePolicy -Property Id, DisplayName, Description


if ($DCPs.Length -eq 0) {
    Write-Host "No policies found" -ForegroundColor Red
    break
}

Write-Host 
Write-Host "Compliance Policies:"
$DCPs | Format-Table -Property Id, DisplayName, Description

Write-Host
$ExportPath = Read-Host -Prompt "Please specify a path to export each policy's JSON file to e.g. C:\IntuneOutput"

# If the directory path doesn't exist prompt user to create the directory
if (!(Test-Path "$ExportPath")) {
    
    Write-Host
    Write-Host "Path '$ExportPath' doesn't exist, do you want to create this directory? Y or N?" -ForegroundColor Yellow

    $Confirm = Read-Host

    if ($Confirm -eq "y" -or $Confirm -eq "Y") {

        New-Item -ItemType Directory -Path "$ExportPath" | Out-Null
        Write-Host

    }
    else {

        Write-Host "Creation of directory path was cancelled..." -ForegroundColor Red
        Write-Host
        break
    }
}

#Loop through each Compliance policy and export the JSON file
Write-Host "Exporting Compliance policies..." -ForegroundColor Green
Write-Host
foreach ($DCPId in $DCPs.Id) {
    try {
        $DCP = Get-MgDeviceManagementDeviceCompliancePolicy -DeviceCompliancePolicyId $DCPId
    }
    catch {
        Write-Host "An error occurred while retrieving the Compliance Policy with the id '$DCPId', please provide a valid policy id..." -f Red
        break
    }
    $DCP | ConvertTo-Json -Depth 10 | Out-File "$ExportPath\CompliancePolicy_$($DCP.DisplayName)_$($DCP.Id).json"
    if ($? -eq $true) {
        Write-Host "JSON file created and can be found at $ExportPath\CompliancePolicy_$($DCP.DisplayName)_$($DCP.Id).json" -ForegroundColor Green
    }
}

Write-Host
