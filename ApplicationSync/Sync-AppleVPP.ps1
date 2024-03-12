Import-Module Microsoft.Graph.DeviceManagement.Actions

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Get VPP tokens
$VPPTokens = Get-MgDeviceAppManagementVppToken
$VPPTokens | Format-Table -AutoSize

# If no VPP tokens found, exit
if ($VPPTokens.Count -eq 0) {      
    Write-Host "No VPP tokens found."
    return
}
# If only one VPP token found, sync it
elseif ($VPPTokens.Count -eq 1) {
    Sync-MgDeviceAppMgtVppTokenLicense -VppTokenId $VPPTokens.Id
}
# If multiple VPP tokens found, prompt for which one to sync
else {
    Write-Host "Multiple VPP tokens found. Please specify the Id of the VPP token to sync." 
    $VPPTokenId = Read-Host -Prompt "Enter VPP token Id to initiate sync"
    Sync-MgDeviceAppMgtVppTokenLicense -VppTokenId $VPPTokenId
}