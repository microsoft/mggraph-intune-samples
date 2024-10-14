# requires -Module Microsoft.Graph.Beta.DeviceManagement
# requires -Module Microsoft.Graph.Authentication

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Import the CSV file containing the profile names
# The CSV file should not have a header row
$csvPath = "" # Path to the CSV file containing the profile names

$csv = Import-Csv -Header "ProfileNames" -Path $csvPath 

# Create the profiles and tokens for each profile name in the CSV file
foreach ($row in $csv) {
    # Max Token validity in seconds (90 days)
    $TokenValidityInSeconds = 7776000
    $profileName = $row.ProfileNames
    try {
        # Create the profile and capture the profile ID
        $profileId = (New-MgBetaDeviceManagementAndroidForWorkEnrollmentProfile -DisplayName $profileName -Description "AE Dedicated Enrollment Profile for $profileName").Id 

        # Create the token for the profile
        New-MgBetaDeviceManagementAndroidForWorkEnrollmentProfileToken -AndroidForWorkEnrollmentProfileId $profileId -TokenValidityInSeconds $TokenValidityInSeconds
        Write-Host "Profile $profileName created successfully"
    }
    catch {
        Write-Host "Error creating profile or token for $profileName"
        Write-Host "Exception Message: $($_.Exception.Message)"
    }
}

# Different implementation for the loop above for faster parallel processing
## Requires PowerShell 7 or later 
<#
$csv | ForEach-Object -Parallel {
    $TokenValidityInSeconds = 7776000
    $profileName = $_.ProfileNames
    try {
        $profileId = (New-MgBetaDeviceManagementAndroidForWorkEnrollmentProfile -DisplayName $profileName -Description "AE Dedicated Enrollment Profile for $profileName").Id 
        New-MgBetaDeviceManagementAndroidForWorkEnrollmentProfileToken -AndroidForWorkEnrollmentProfileId $profileId -TokenValidityInSeconds $TokenValidityInSeconds
        Write-Host "Profile $profileName created successfully"
    }
    catch {
        Write-Host "Error creating profile or token for $profileName"
        Write-Host "Exception Message: $($_.Exception.Message)"
    }
} -ThrottleLimit 20
#>
