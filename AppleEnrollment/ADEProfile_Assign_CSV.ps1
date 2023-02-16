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

# Retrieve ADE (DEP) tokens
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
    $ADETokenId = Read-Host "More than one ADE token found. Please enter the token ID and press enter to see associated profiles"
}

if ($ADETokenId -eq $null -or $ADETokenId -notin $ADETokens.Id) {
    Write-Host "Invalid token ID entered. Exiting."
    break
}

# Retrieve enrollment profiles associated with the ADE token
$EnrollmentProfiles = Get-MgDeviceManagementDepOnboardingSettingEnrollmentProfile -DepOnboardingSettingId $ADETokenId 
$EnrollmentProfiles | Select-Object DisplayName, Id | Format-Table -AutoSize

$EnrollmentProfileToAssign = Read-Host "Please enter the enrollment profile ID to assign to the device and press enter"

# Confirming enrollment profile ID is valid
if (($EnrollmentProfileToAssign -eq $null) -or ($EnrollmentProfileToAssign -notin $EnrollmentProfiles.Id)) {
    Write-Host "Invalid profile ID entered. Exiting."
    break
}
else {
    #Importing .csv with serial numbers
    $CSVPath = Read-Host -Prompt 'Enter the full path of the csv file that includes the serial numbers you want to assign the enrollment profile to'
    $CSVPath = $CSVPath.replace('"', '')
    $Serials = Import-Csv $CSVPath -Header "deviceIds"
    $DeviceCount = $Serials.Count
    Write-Host $Serials.Count'devices read from .csv'

    if ($Serials.Count -eq 0) {
        Write-Host "No devices found in .csv. Exiting."
        break
    }

    #Confirming enrollment profile assignment
    $ConfirmAssign = Read-Host -Prompt  'Please confirm you would like to assign the enrollment profile (Y/N)'

    if ($ConfirmAssign -notmatch "[yYnN]") {
        do {
            $ConfirmAssign = Read-Host -Prompt 'Invalid selection. Please confirm you would like to assign the enrollment profile (Y/N)'
        } until ($ConfirmAssign -match "[yYnN]")
    }


    #Performing enrollment profile assignment
    If ($ConfirmAssign -match "[yY]") { 
        Update-MgDeviceManagementDepOnboardingSettingEnrollmentProfileDeviceProfileAssignment -DepOnboardingSettingId $ADETokenId  -EnrollmentProfileId $EnrollmentProfileToAssign -DeviceIds $Serials.deviceIds
        if ($?) {
            Write-Host "Enrollment profile $EnrollmentProfileToAssign successfully assigned  to $DeviceCount devices." -ForegroundColor Green
        }
        else {
            Write-Host "Enrollment profile assignment failed." -ForegroundColor Red
        }
    }
    # Exiting if user does not confirm enrollment profile assignment
    If ($ConfirmAssign -match "[nN]") {
        Write-Host "Exiting..."
        Exit
    }
}


