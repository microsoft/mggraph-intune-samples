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

Write-Host
$ExportPath = Read-Host -Prompt "Please specify a path to export the policy data to e.g. C:\IntuneOutput"

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

Write-Host
Get-MgDeviceAppMgtManagedAppRegistration | Export-Csv -Path "$ExportPath\AppRegistrationSummary.csv" 
##if the export fails, the script will stop
if ($? -eq $false) {
    break
}
else {
    Write-Host "Report created and can be found at $ExportPath" -ForegroundColor Green
}


