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

# Getting all Platform Enrollment Restrictions
$PlatformRestrictions = Get-MgBetaDeviceManagementDeviceEnrollmentConfiguration -Filter ("DeviceEnrollmentConfigurationType eq 'singlePlatformRestriction'")

foreach ($Policy in $PlatformRestrictions) {
    Write-Host
    #Check if the policy is the Default Platform Restrictions policy as it has a different structure
    if ($Policy.Id.Contains("DefaultPlatformRestrictions")) {
        Write-Host "Default Policy:" $Policy.DisplayName
        Write-Host 'Priority:'$Policy.Priority''
        Write-Host "Android Enterprise restrictions: " 
        $Policy.AdditionalProperties.androidForWorkRestriction | Format-Table -HideTableHeaders
    }

    #Check if the policy is a Single Platform Restriction policy and if it is for Android Enterprise
    elseif ($Policy.Id.Contains("SinglePlatformRestriction") -and $Policy.AdditionalProperties.platformType.Contains("androidForWork")) {
        Write-Host $Policy.DisplayName
        Write-Host 'Priority:'$Policy.Priority''
        $Assignments = Get-MgBetaDeviceManagementDeviceEnrollmentConfigurationAssignment -DeviceEnrollmentConfigurationId $Policy.Id

        Write-Host "Android Enterprise restrictions: " 
        $Policy.AdditionalProperties.platformRestriction | Format-Table -HideTableHeaders
        
        Write-Host "Assigned to:"
        foreach ($Id in $Assignments.Id) {
            #String manipulation to get the group ID from the assignment ID
            $groupId = -join (($Id -split '_')[1..1])
            $groupName = (Get-MgGroup -GroupId $groupId).DisplayName
            Write-Host $groupName "(Group Id: $groupId)"
        }
    }
}

