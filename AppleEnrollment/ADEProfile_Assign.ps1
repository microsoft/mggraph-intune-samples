Import-Module Microsoft.Graph.Beta.DeviceManagement.Enrollment
Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Retrieve ADE (DEP) tokens
$ADETokens = Get-MgBetaDeviceManagementDepOnboardingSetting

if ($ADETokens.Count -eq 0) {
    Write-Host "No ADE tokens found."
    break
}
elseif ($ADETokens.Count -eq 1) {
    $ADETokenId = $ADETokens.Id
    
}
elseif ($ADETokens.Count -gt 1) {
    $ADETokens | Select-Object -Property TokenName, Id, AppleIdentifier, LastSuccessfulSyncDateTime, LastSyncTriggeredDateTime, LastSyncErrorCode | Format-Table -AutoSize
    $ADETokenId = Read-Host "More than one ADE token found. Please enter the token ID and press enter to see associated profiles"
}

if ($ADETokenId -eq $null -or $ADETokenId -notin $ADETokens.Id) {
    Write-Host "Invalid token ID entered. Exiting."
    break
}

$EnrollmentProfiles = Get-MgBetaDeviceManagementDepOnboardingSettingEnrollmentProfile -DepOnboardingSettingId $ADETokenId 
$EnrollmentProfiles | Select-Object DisplayName, Id | Format-Table -AutoSize

$EnrollmentProfileToAssign = Read-Host "Please enter the enrollment profile ID to assign to the device and press enter"

if (($EnrollmentProfileToAssign -eq $null) -or ($EnrollmentProfileToAssign -notin $EnrollmentProfiles.Id)) {
    Write-Host "Invalid profile ID entered. Exiting."
    break
}
else {
    $DeviceSerialNumber = Read-Host "Please enter the device serial number you want to assign the enrollment profile to and press enter"
    Update-MgBetaDeviceManagementDepOnboardingSettingEnrollmentProfileDeviceProfileAssignment -DepOnboardingSettingId $ADETokenId -EnrollmentProfileId $EnrollmentProfileToAssign -DeviceIds $DeviceSerialNumber 
    if ($?) {
        Write-Host "Enrollment profile $EnrollmentProfileToAssign assigned successfully to $DeviceSerialNumber." -ForegroundColor Green
    }
    else {
        Write-Host "Enrollment profile assignment failed." -ForegroundColor Red
    }
}
