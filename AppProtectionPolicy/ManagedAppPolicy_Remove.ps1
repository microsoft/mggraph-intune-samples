Import-Module Microsoft.Graph.Devices.CorporateManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Using get-mgdeviceappmanagementandroid/iosmanagedappprotection rather than get-mgdeviceappmanagementmanagedapppolicy to filter out app configuration policies
$AndroidPolicies = Get-MgDeviceAppManagementAndroidManagedAppProtection -Property Id, DisplayName, Description
$iOSPolicies = Get-MgDeviceAppManagementiOSManagedAppProtection -Property Id, DisplayName, Description

Write-Host 
Write-Host "Android Policies:"
$AndroidPolicies | Format-Table -Property Id, DisplayName, Description
Write-Host "iOS Policies:"
$iOSPolicies | Format-Table -Property Id, DisplayName, Description

#prompt user to select policy to delete
$Id = Read-Host -Prompt "Please provide the policy Id to delete"
$Confirm = Read-Host -Prompt "Are you sure you want to delete the policy with the id '$Id'? (Y/N)"

#confirm user wants to delete policy and handle cases properly
if ($Confirm -ne "Y" -and $Confirm -ne "N") {
    Write-Host "Invalid input, please enter 'Y' or 'N'..." -f Red
    break
}
switch ($Confirm) {
    "Y" { 
        #no policy id provided
        if ($Id -eq "" -or $Id -eq $null) {
            Write-Host "No Managed App Policy id specified, please provide a valid policy id..." -f Red
            break
        }
        #try to delete
        else { 
            try {
                Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/v1.0/deviceAppManagement/managedAppPolicies/$Id" -Method DELETE
                Write-Host "Managed App Policy with the id '$Id' has been successfully deleted..." -f Green
            }
            catch {
                Write-Host "An error occurred while deleting the Managed App Policy with the id '$Id'..." -f Red
                break
            }
        }
    }
    "N" { 
        Write-Host "No policies have been deleted, exiting..." -f Red
    }
}