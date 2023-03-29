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

Select-MgProfile -Name "beta"

$ExportPath = Read-Host -Prompt "Please specify a path to export the hardware information .csv file e.g. C:\IntuneOutput"

# If the directory path doesn't exist prompt user to create the directory
if (!(Test-Path "$ExportPath")) {


    New-Item -ItemType Directory -Path "$ExportPath" | Out-Null
}

$AllDevices = Get-MgDeviceManagementManagedDevice -All
$AllDevices | Select-Object id, activationLockBypassCode, iccid, udid , ethernetMacAddress, physicalMemoryInBytes, bootstrapTokenEscrowed, processorArchitecture -ExpandProperty hardwareinformation | Export-Csv -Path "$ExportPath\HardwareDetails.csv" -NoTypeInformation