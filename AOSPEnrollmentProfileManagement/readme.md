# Intune Android Open Source Project Enrollment Profile Management script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

Within this section there are the following scripts with the explanation of usage.

### 1. AOSP_Token_Renew_Export.ps1
This script gets any Android Open Source Project (AOSP) Device Owner Enrollment Profiles from the Intune Service that you have authenticated with.
It can renew the tokens, and export them as .json files or as QR code .png files.

WARNING: Anyone with these QR codes or JSON files can enroll a device into your tenant. Please ensure they are kept secure.

### Running the script
1. Running the script in an IDE such as VS Code will display your AOSP enrollment profiles:

####
```PowerShell
.\AOSP_Token_Renew_Export.ps1
```

```
Id                                   DisplayName                  EnrollmentMode                         TokenCreationDateTime TokenExpirationDateTime
--                                   -----------                  --------------                         --------------------- -----------------------
5bc2d8ca-f191-0000-8426-70389bbkms08 Test AOSP UDA                corporateOwnedAOSPUserAssociatedDevice 11/9/2023 3:33:32 PM  2/7/2024 3:33:32 PM
0a547605-1111-4bbc-b90f-4da3f0383hd7 Test AOSP NO UDA             corporateOwnedAOSPUserlessDevice       11/9/2023 3:33:33 PM  2/7/2024 3:33:33 PM
```

2. To renew the AOSP enrollment profile tokens, run the ```Invoke-AOSPEnrollmentTokenRenewal``` function specifying the token Ids ```-AndroidDeviceOwnerEnrollmentProfileId``` (or ```-All```) and the token validity in seconds (If unspecified, 7776000 is used which is the max token lifetime of 90 days) ```-TokenValidityInSeconds 2592000```

3. To export the AOSP enrollment profile tokens as .json files, run the ```Export-AOSPEnrollmentTokenJSON``` function specifying the token Ids ```-AndroidDeviceOwnerEnrollmentProfileId``` (or ```-All```) and the folder path to export the files ```-ExportPath C:\IntuneOutput```

4. To export the AOSP enrollment profile tokens as .json files, run the ```Export-AOSPEnrollmentTokenQRCode``` function specifying the token Ids ```-AndroidDeviceOwnerEnrollmentProfileId``` (or ```-All```) and the folder path to export the files ```-ExportPath C:\IntuneOutput```


Examples:

```PowerShell
Invoke-AOSPEnrollmentTokenRenewal  -All
```

```PowerShell
Invoke-AOSPEnrollmentTokenRenewal -AndroidDeviceOwnerEnrollmentProfileId 0988e8e1-74da-4d77-0000-a6a0d6f017d8 -TokenValidityInSeconds 2592000
```

```PowerShell
Export-AOSPEnrollmentTokenQRCode -AndroidDeviceOwnerEnrollmentProfileId aaf57534-1111-4872-a7ce-99e37209261g -ExportPath C:\IntuneOutput
```

```PowerShell
Export-AOSPEnrollmentTokenQRCode -All -ExportPath C:\IntuneOutput
```

```PowerShell
Export-AOSPEnrollmentTokenJSON -AndroidDeviceOwnerEnrollmentProfileId aaf57534-1111-4872-a7ce-99e37209261g -ExportPath C:\IntuneOutput
```

```PowerShell
Export-AOSPEnrollmentTokenJSON -All -ExportPath C:\IntuneOutput
```
