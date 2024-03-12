Import-Module Microsoft.Graph.Devices.CorporateManagement
Import-Module Microsoft.Graph.Users

<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

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

# Get the user's ID from UPN
$UserUPN = Read-Host "Enter the UPN of the user"

$UserId = (Get-MgUser -Property "id" -Filter "userPrincipalName eq '$UserUPN'").Id

if ($UserId -eq $null) {
    Write-Host "User not found, please enter a valid UPN..." -f Red
    break
}

Write-Host "User found..." -f Green

# Get the user's managed apps registrations
$AppRegistrations = (Get-MgUserManagedAppRegistration -UserId $UserId -Property UserId, DeviceName, DeviceTag, CreatedDateTime, LastSyncDateTime) 

# Display the user's managed apps registrations
if ($AppRegistrations -eq $null) {
    Write-Host "No managed apps registrations found for this user..." -f Red
    break
}
else {
    # Display the user's managed apps registrations
    Write-Host "Managed apps registrations on devices for this user:"
    $AppRegistrations | Select-Object -Property UserId, DeviceName, DeviceTag, CreatedDateTime, LastSyncDateTime  | Sort-Object -Property DeviceTag | Format-Table -AutoSize
    
    # Prompt the user to to see if they want to wipe all managed apps on all devices or just one device
    $wipeAll = Read-Host "Do you want to issue wipe requests to ALL managed apps on ALL devices found for this user? (Y/N)"
}

# Wipe all managed apps on all devices for this user
switch ($wipeAll) {
    "Y" {
        Write-Host "Wiping all managed apps on all devices for this user..."
        foreach ($Registration in $AppRegistrations) {
            Clear-MgUserManagedAppRegistrationByDeviceTag -UserId $UserId -DeviceTag $Registration.DeviceTag
        }
    }
    # Wipe managed apps on a specific device for this user
    "N" {
        $SelectedTag = Read-Host "Which device do you want to wipe managed apps on? (Enter the DeviceTag)"
        Write-Host "Wiping all managed apps on device with DeviceTag $SelectedTag for this user..."
        Clear-MgUserManagedAppRegistrationByDeviceTag -UserId $UserId -DeviceTag $SelectedTag 
    }
}