Import-Module Microsoft.Graph.Groups
Import-Module Microsoft.Graph.DeviceManagement
Import-Module Microsoft.Graph.Identity.DirectoryManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

Select-MgProfile "v1.0"

#Filter Intune devices by UPN
$UPN = Read-Host -Prompt "Enter the UPN of the user whose device will be added to the group"
$Devices = Get-MgDeviceManagementManagedDevice -Filter "UserPrincipalName eq '$UPN'"  | Select-Object  ManagedDeviceName, Id, DeviceName, Manufacturer, AzureAdDeviceId, UserPrincipalName, UserId
if ($null -eq $Devices) {
    Write-Output "No devices found for user $UPN" 
    return
}

#List the users devices
$Devices | Format-Table -AutoSize
$DeviceId = Read-Host -Prompt "Enter the Intune Device ID (Id column) of the device to be added to the group"

#Find the Azure AD Object ID of the device using the Azure AD Device ID
$AzureAdDeviceId = ($Devices | Where-Object { $_.Id -eq $DeviceId }).AzureAdDeviceId
$AzureADObjectId = (Get-MgDevice -Filter "DeviceId eq '$AzureAdDeviceId'").Id

if ($null -eq $AzureADObjectId) {
    Write-Output "No Azure AD Object ID found for device $AzureAdDeviceId."
    return
}

#Find the Azure AD Group ID to add the device to
$AzureADGroups = Read-Host -Prompt "Enter the Azure AD Group Name to add the device to"
#From the filtered list of groups, select only the groups that are security enabled, not mail enabled, and not dynamic
$Groups = Get-MgGroup -Filter "DisplayName eq '$AzureADGroups'" | Select-Object DisplayName, Id, Description, GroupTypes, Mail, MailEnabled, SecurityEnabled | Where-Object { $_.SecurityEnabled -eq $true -and $_.MailEnabled -eq $false -and $_.GroupTypes -notcontains 'DynamicMembership' }
if ($null -eq $Groups) {
    Write-Output "No groups found with name $AzureADGroups" 
    return
}

$Groups | Select-Object DisplayName, Id, Description, GroupTypes, SecurityEnabled | Format-Table -AutoSize
$SelectedGroupId = Read-Host -Prompt "Enter the Group ID (Id column) of the group to add the device to"

#Add the device to the group
New-MgGroupMember -GroupId $SelectedGroupId -DirectoryObjectId $AzureADObjectId

#If the command was successful, write confirmation output
if ($?) {
    Write-Output "AAD Device $AzureAdDeviceId succesfully added to group $SelectedGroupId."
}