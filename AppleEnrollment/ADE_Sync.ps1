Import-Module Microsoft.Graph.DeviceManagement.Enrolment
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

# Get-MgDeviceManagementDepOnboardingSetting not yet available in v1.0, using beta endpoint
Select-MgProfile -Name beta

$ADETokens = Get-MgDeviceManagementDepOnboardingSetting

if ($ADETokens.Count -eq 0) {
    Write-Host "No ADE tokens found."
    break
}
elseif ($ADETokens.Count -eq 1) {
    $ADETokenId = $ADETokens.Id
    
}
elseif ($ADETokens.Count -gt 1) {
    $ADETokens | Select-Object -Property TokenName, Id, AppleIdentifier, LastSuccessfulSyncDateTime, LastSyncTriggeredDateTime, LastSyncErrorCode | Format-Table -AutoSize
    $ADETokenId = Read-Host "More than one ADE token found. Please enter the token ID to sync and press enter"
}

Sync-MgDeviceManagementDepOnboardingSettingWithAppleDeviceEnrollmentProgram -DepOnboardingSettingId $ADETokenId


