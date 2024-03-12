Import-Module Microsoft.Graph.Beta.DeviceManagement.Enrollment

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# get the path to save the QR code image
Write-Host
$ExportPath = Read-Host -Prompt "Please specify a path to save the QR code image e.g. C:\IntuneOutput"
Write-Host

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

# Get all Android dedicated device profiles
$EnrollmentProfiles = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -Filter "EnrollmentMode eq 'corporateOwnedDedicatedDevice'"
$EnrollmentProfiles | Format-Table -AutoSize
Write-Host

# If there are no Android dedicated device profiles, exit
if ($EnrollmentProfiles.Count -eq 0) {
    Write-Host "No Android dedicated device profiles found. Exiting..."
    exit
}
# If there is only one Android dedicated device profile, use that
elseif ($enrollmentProfiles.Count -eq 1) {
    $AndroidDeviceOwnerEnrollmentProfileId = $enrollmentProfiles[0].id
    $AndroidDeviceOwnerEnrollmentProfileName = $enrollmentProfiles[0].displayName
}
# If there are multiple Android dedicated device profiles, prompt user to select one
elseif ($enrollmentProfiles.Count -gt 1) {
    $AndroidDeviceOwnerEnrollmentProfileId = Read-Host "Multiple Android dedicated device profiles found. Please enter the Id of the profile you want to export the QR code for"
    $AndroidDeviceOwnerEnrollmentProfileName = $enrollmentProfiles | Where-Object { $_.id -eq $AndroidDeviceOwnerEnrollmentProfileId } | Select-Object -ExpandProperty displayName
    Write-Host
}

# Get user confirmation to export the QR code
Write-Host "- You are about to export the QR code for the Dedicated Device Enrollment Profile $AndroidDeviceOwnerEnrollmentProfileName
- Anyone with this QR code can enroll a device into your tenant. Please ensure it is kept secure.
- If you accidentally share the QR code, you can immediately expire it in the Intune UI.
- Devices already enrolled will be unaffected." 
Write-Host

$confirmExport = Read-Host "Do you want to continue? (Y/N)"

# If user confirms, export the QR code
switch ($confirmExport) {
    "Y" {
        $QR = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -AndroidDeviceOwnerEnrollmentProfileId $AndroidDeviceOwnerEnrollmentProfileId -Select qrCodeImage
        $QRType = $QR.qrCodeImage.type
        $QRValue = $QR.qrCodeImage.value
        
        # Creating file
        $imageType = $QRType.split("/")[1]
        $filename = "$ExportPath\$AndroidDeviceOwnerEnrollmentProfileName.$imageType"
        [IO.File]::WriteAllBytes($filename, $QRValue)

        # Check if file was created
        if (Test-Path $filename) {

            Write-Host "Success: " -NoNewline -ForegroundColor Green
            Write-Host "QR code exported to " -NoNewline
            Write-Host "$filename" -ForegroundColor Yellow
            Write-Host

        }
        else {
            Write-Host "Unable to create file." -ForegroundColor Red
        }
    }
    # If user doesn't confirm, exit
    "N" {
        exit
    }
}

