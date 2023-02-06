Import-Module Microsoft.Graph.DeviceManagement

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

Select-MgProfile -Name v1.0
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"
#endregion

####################################################

# Setting application AAD Group to assign Policy

$AADGroup = Read-Host -Prompt "Enter the Azure AD Group ID where policies will be assigned"


$TargetGroupId = Get-MgGroup -GroupId "$AADGroup"

if ($null -eq $TargetGroupId -or $TargetGroupId -eq "") {

    Write-Host "AAD Group - '$AADGroup' doesn't exist, please specify a valid AAD Group..." -ForegroundColor Red
    Write-Host
    exit

}

# Hashtable for Target Group Assignment
$TargetGroupObject = @{
    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
    groupId       = $TargetGroupId.id
}

####################################################

$PolicyId = ""
if ($PolicyId -eq "") {

    Write-Host "Please enter the Device Configuration Policy ID to assign to '$AADGroup'..." -ForegroundColor Yellow
    Write-Host
    $PolicyId = Read-Host -Prompt "Enter the Device Configuration Policy ID"

}
$DCP = Get-MgDeviceManagementDeviceConfiguration -DeviceConfigurationId "$PolicyId"

if ($DCP) {

    $Assignment = New-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $DCP.id -Target $TargetGroupObject
    Write-Host "Assigned '$AADGroup' to $($DCP.displayName)/$($DCP.id)" -ForegroundColor Green
    Write-Host

}

else {

    Write-Host "Can't find Device Configuration Policy with ID '$PolicyId'..." -ForegroundColor Red
    Write-Host

}