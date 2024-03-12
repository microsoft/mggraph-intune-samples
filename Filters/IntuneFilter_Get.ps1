<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

Import-Module Microsoft.Graph.Beta.Devices.CorporateManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

####################################################

$Filters = Get-MgBetaDeviceManagementAssignmentFilter

if($Filters){

    foreach($Filter in $Filters){

        Write-Host "Filter Display Name:" $Filter.displayName -ForegroundColor Cyan
        $filter

    }

}

else {

    Write-Host "No Filters created..." -ForegroundColor Yellow
    Write-Host

}