Import-Module Microsoft.Graph.DeviceManagement

<#

.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.

#>
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

#endregion

####################################################
$DeviceConfigId = '<Intune Device Configuration ID>'
$CP = Get-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $DeviceConfigId

if ($CP) {
    Write-Host "Removing device configuration policy" $CP.displayName -ForegroundColor Yellow
    Remove-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId $DeviceConfigId
}
else {

    Write-Host "Device Configuration Policy doesn't exist..."
    Write-Host

}
