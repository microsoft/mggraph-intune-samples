# Intune Managed Device script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. Get_DeviceAction_Set.ps1
This script scans the installed Graph PowerShell SDK for available remote actions based on specified Graph version and asks the user for a remote action to return the parameters for.

There are the following functions used:


#### Get-IntuneRemoteActions - Function
This function is used to return available remote actions from the Graph PowerShell SDK. It supports paramater -MgProfile to specify a Graph version.
```PowerShell
# Returns all Graph PowerShell SDK remote actions for the specified Graph beta version
Get-IntuneRemoteActions -MgProfile beta

# Returns all Graph PowerShell SDK remote actions for the specified Graph v1.0 version
Get-IntuneRemoteActions -MgProfile "v1.0"

# Returns all Graph PowerShell SDK remote actions for Graph v1.0 and beta version
Get-IntuneRemoteActions
```

### 2. ManagedDeviceOverview_Get.ps1
This script returns a report of all managed devices added to the Intune Service that you have authenticated with.

Sample data which is returned:

```
Total: 21

Name                           Value
----                           -----
macOSCount                     1
androidWorkProfileCount        0
androidCorporateWorkProfileCo… 0
linuxCount                     0
windowsCount                   5
androidFullyManagedCount       1
configMgrDeviceCount           0
androidDedicatedCount          0
androidDeviceAdminCount        0
windowsMobileCount             0
iosCount                       2
aospUserlessCount              0
chromeOSCount                  12
aospUserAssociatedCount        0
androidCount                   1
unknownCount                   0
```


### 3.ManagedDevices_Apps_Get.ps1
This script is used to return all Managed Devices application installation inventory. The following output is a sample output.
```
Id                                                               DeviceCount DisplayName                                                        Platform Publisher SizeInByte Version
--                                                               ----------- -----------                                                        -------- --------- ---------- -------
95117eb3ae0810afe8ea364270a6ff6b50c7b444ecb6c21981566ad2c1411de6 1           A8C1C166-BDAC-44C9-9CDF-A88B979EAC5B                               unknown            0          1.0.0.0
1b0398a6a9882ee10bb20e660f12dc98185d4d219819519d7d1ac0c96e14836a 1           Authenticator                                                      unknown            0          13 (6.6.8)
00002b5351d3398d8c38ee92e19e4bb41ed500000904                     7           Configuration Manager Support Center                               unknown            0          5.2203.1086.1000
77598de330e27d07b79865f72c363b40c29575d0675b305c1ab2383e85c727bf 1           Edge                                                               unknown            0          107.0.1418.52 (107.1418.52)
00007dd4e4407f9ca12d123d3205514c3f030000ffff                     1           Intel(R) Processor Graphics                                        unknown            0          20.19.15.4568
00006df03df8837a3a052dcfd1c0cff3539f0000ffff                     1           Microsoft 365 Apps for enterprise - en-us                          unknown            0          16.0.16227.20172
0000992c0fcae3f5ce759ac2046d43f1a9970000ffff                     1           Microsoft 365 Apps for enterprise - en-us                          unknown            0          16.0.16130.20156
```


### 4. ManagedDevices_DeviceOwnership_Set.ps1
This script is used to set a managed device ownership property in the Intune Service.

There are the following functions used:

#### Set-IntuneDeviceOwnership - Function
This function is used to set a managed device ownership property in the Intune Service. It has two mandatory parameters -ManagedDeviceId and -ManagedDeviceOwnerType.
```PowerShell
Set-IntuneDeviceOwnership -ManagedDeviceId $ManagedDeviceId -ManagedDeviceOwnerType $ManagedDeviceOwnerType
It has two mandatory parameters -ManagedDeviceId and -ManagedDeviceOwnerType.

+ ManagedDeviceId - The ID of the managed device in the Intune Service
+ ManagedDeviceOwnerType - The owner type of the device i.e. personal or company
```


### 5. ManagedDevices_Get.ps1
This script returns all managed devices added to the Intune Service that you have authenticated with. It also contains commented examples to only return specific operating systems, by UPN, and by DeviceId.
```PowerShell
# Get-MgDeviceManagementManagedDevice -Filter "OperatingSystem eq 'iOS'"
# Get-MgDeviceManagementManagedDevice -Filter "userPrincipalName eq '$UPN'"
# Get-MgDeviceManagementManagedDeviceUser -DeviceId $DeviceId
```

### 6. ManagedDevices_Hardware_Get.ps1
This script returns all managed devices hardware information that have been added to the Intune Service that you have authenticated with.

The script will prompt for an output Directory so that it can export a CSV of the managed device hardware information.


### 7. Win_PrimaryUser_Get.ps1
This script prompts returns the Primary user of an Intune managed Windows device when provided a device name and will also return the Registered Owner and Registered Users of the associated Azure AD device object.

##### Example usage
```
# Gets all win devices and outputs Intune Primary User, Registered Owner and Registered User
.\Win_PrimaryUser_Get.ps1
Enter the device name to search for: testclient01
```
##### Example output
```
Device Name: testclient01
Intune Device Id: 26dc5bad-2166-4f37-a3ba-0000eca51472
Intune Primary user id: 8081aefe-ce81-4e60-8ff7-000046176b19
AAD Registered Owner:
Id: 8081aefe-ce81-4e60-8ff7-000046176b19
Name: Test User 1
AAD Registered Users:
Id: 8081aefe-ce81-4e60-8ff7-000046176b19
Name: Test User 1
```


### 8. Win_PrimaryUser_Set.ps1
This script can be used to set an Intune managed Windows device primary user when provided a device name and UPN.

##### Example usage
```
.\Win_PrimaryUser_Set.ps1
Enter the device name to search for: testclient01
DeviceName Id                                   UserPrincipalName                    UserId
---------- --                                   -----------------                    ------
testclient01    26dc5bad-2166-4f37-a3ba-0000eca51472 testuser01@contoso.com 8081aefe-ce81-4e60-8ff7-000046176…

Enter the Intune Device ID (Id column) of the device id to set a new primary user for: 26dc5bad-2166-4f37-a3ba-0000eca51472
Enter the UPN of the user to set as the primary user for the selected device: testuser02@contoso.com
```


### 9. Win_PrimaryUser_Delete.ps1
This script can be used to remove the primary user from an Intune managed Windows device when provided a device name/device id.
##### Example usage
```
.\Win_PrimaryUser_Delete.ps1
Enter the device name to search for: testclient01
DeviceName Id                                   UserPrincipalName                    UserId
---------- --                                   -----------------                    ------
testclient01    26dc5bad-2166-4f37-a3ba-0000eca51472 testuser01@contoso.com 8081aefe-ce81-4e60-8ff7-000046176…

Enter the Intune Device ID (Id column) of the device id to remove the primary user from: 26dc5bad-2166-4f37-a3ba-0000eca51472
```

### 10. ManagedDevices_Add_ToAADGroup.ps1
This script can be used to add an Intune managed device to a specified AAD group. The script prompts for an associated user's UPN, prompts the device to add, and prompts for a group name to add them to.


### 11. ManagedDevices_NoBitLockerKey_Get.ps1
This script returns all Windows device records in Entra ID that do not have a BitLocker recovery key backed up. It also returns a list of managed Intune device records whose corresponding Entra ID device ID does not have a backed up BitLocker recovery key. Note that there is typically overlap between these two datasets. These device lists can also be exported to .csv. using the examples in the last script comment.
##### Example output
```
150 Windows device records found in Entra ID
2 Windows device records found in Entra ID without BitLocker recovery keys:

DisplayName     DeviceId
-----------     --------
CATTESTCL03     c03f701b-0000-4360-921f-49fs08f8asy7
DESKTOP-SFPR123 7ab07aac-0000-49c8-ac13-0cf8bbe16f69

148 Windows device records found in Intune
2 of these do not have BitLocker recovery keys in Entra ID:

Id                                   AzureAdDeviceId                      DeviceName      UserPrincipalName                    IsEncrypted
--                                   ---------------                      ----------      -----------------                    -----------
ce7d7ac4-d7e2-1234-a3e4-0cf8bbe16f69 c03f701b-0000-4360-921f-49fs08f8asy7 CATTESTCL03     testuser1@contoso.com                      False
cjde98a8-8b13-1234-b54b-ee0000019263 7ab07aac-0000-49c8-ac13-0cf8bbe16f69 DESKTOP-SFPR123 testuser2@contoso.com                      False
```
