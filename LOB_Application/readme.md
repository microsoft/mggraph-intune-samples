# Intune Line of Business App Upload script samples

This repository of PowerShell sample scripts show how to retrieve, create, delete, and modify Intune service resources using cmdlets from the Microsoft Graph PowerShell SDK.

Documentation for Intune and Microsoft Graph can be found here [Intune Graph Documentation](https://developer.microsoft.com/en-us/graph/docs/api-reference/beta/resources/intune_graph_overview).

Documentation for the Microsoft Graph PowerShell SDK can be found here [Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0).

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account.

Within this section there are the following scripts with the explanation of usage.

### Introduction
The Microsoft Graph API for Intune provides the same facilities as does the Intune user interface so, automating manual tasks is a relatively straightforward programming process. In the case of a line of business (LOB) application, there are several additional steps required to complete the upload of the application file. This readme provides an overview and step-by-step guidance for uploading your line of business applications to Intune.

#### Flow of the process
1.	Identify the key metadata required to create the application.
2.	Submit information in request body in JSON format and POST to new LOB App
3.	Create a content version for the LOB application and POST to LOB App
    +	Create a new file entry in the Content Version
    +	Wait for File entry  SAS URI in the service to be created and ready
    +	LOB app ready is now for content.
4.	Encrypt the file for upload and call the upload
5.	Upload to Azure Storage
6.	Commit the file to the reserved LOB app & version

For more in-depth information on the LOB application upload process, see the .readme of the previous version of this script in the (archived repository)
https://github.com/microsoftgraph/powershell-intune-samples/blob/master/LOB_Application/readme.md

### 1. iOS_Application_LOB_App.ps1
The following script sample provides the ability to upload an iOS application to the Intune Service.

### Prerequisites
+ Dependent PowerShell module (Microsoft.Graph.Devices.CorporateManagement)
https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
+	Application metadata for iOS apps
    +	iOS – BundleID, IdentityVersion, ExpirationDateTime
    + The script will attempt to extract the BundleID, IdentityVersion, ExpirationDateTime from the provided .ipa file automatically. However if its unable to parse these values from the app's payload, it prompts for them to be entered manually.

### Running the script
1. Run the script in an IDE such as VS Code:
####
```PowerShell
.\iOS_Application_LOB_App.ps1
```
2. To upload an iOS LOB app into your tenant, run the ```Invoke-iOSLobAppUpload``` function specifying the .ipa path (```-SourceFile```), Intune Display Name (```-displayName```), Publisher (```-publisher```), and description (```-Description```)

```PowerShell
Invoke-iOSLobAppUpload -SourceFile ".\MyLobApp.ipa" -displayName "My Test LOB App" -Publisher "Contoso" -Description "A test iOS app to upload."
```
```
Creating JSON data to pass to the service...
```
Note: If the script is unable to extract and parse these values from the app payload (for example, the app payload is obfuscated or signed), it prompts for them to be entered manually. The .IPA file must be in the same folder path the script is executed from.
```
Unable to extract the app's bundleId (CFBundleIdentifier). Please enter it manually: com.contoso.test       
Unable to extract the app's buildNumber (CFBundleVersion). Please enter it manually: 1.23045.11 
Unable to extract the app's versionNumber (CFBundleShortVersionString). Please enter it manually: 231312
```
3. Once these three required values have been specified, either automatically or manually, the Intune app payload is created and displayed.
```
Name                           Value
----                           -----
minimumSupportedOperatingSyst… {[v9_0, True]}
applicableDeviceType           {[iPad, True], [iPhoneAndIPod, True]}
notes
displayName                    My Test LOB App
developer
owner
informationUrl
privacyInformationUrl
isFeatured                     False
expirationDateTime             2024-10-22T22:17:07Z
description                    A test iOS app to upload.
bundleId                       com.contoso.test
buildNumber                    1.23045.11 
publisher                      Contoso
@odata.type                    #microsoft.graph.iosLOBApp
versionNumber                  1.23022.15
fileName                       contosoTest.ipa
categories                     {}
```
4. Once the app body has been generated and displayed, the app encryption, upload, and creation progress begins.
```
Creating application in Intune...
Creating Content Version in the service for the application...
Encrypting the file 'C:\IntuneApps\MyLobApp.ipa'...
Creating the manifest file used to install the application on the device...
Creating a new file entry in Azure for the upload...
Waiting for the file entry URI to be created...
Uploading file to Azure Storage...
Committing the file into Azure Storage...
Waiting for the service to process the commit file request...
Committing the app body...
Sleeping for 30 seconds to allow patch completion...
```
5. If the end to end process is successful, a success message is displayed:
```
Application 'My Test LOB App' has been successfully uploaded to Intune.
```
6. Lastly, the Intune app payload is requested and displayed:
```
Assignments           : 
Categories            : 
CreatedDateTime       : 6/20/2023 7:52:38 PM
Description           : My Test LOB App
Developer             : 
DisplayName           : L2W
Id                    : 9bcf439e-d7c9-4ff2-9856-b65e1......
InformationUrl        : 
IsFeatured            : False
LargeIcon             : Microsoft.Graph.PowerShell.Models.MicrosoftGraphMimeContent
LastModifiedDateTime  : 6/20/2023 7:52:38 PM
Notes                 : 
Owner                 : 
PrivacyInformationUrl : 
Publisher             : Contoso
PublishingState       : published
AdditionalProperties  : {[@odata.context, https://graph.microsoft.com/v1.0/$metadata#deviceAppManagement/mobileApps/$entity], [@odata.type, #microsoft.graph.iosLobApp], [committedContentVersion, 1], [fileNa...
```
### 2. Win32_Application_Add.ps1
The following script sample provides the ability to upload a Windows application (win32) .intunewin to the Intune Service.

### Prerequisites
To use Win32 app management, be sure you meet the following criteria:

+ Windows 10 version 1607 or later (Enterprise, Pro, and Education versions)

### Running the script
1. Run the script in an IDE such as VS Code:
####
```PowerShell
.\Win32_Application_Add.ps1
```

2. Construct the parameters for the script (see below for more information on the parameters)
```PowerShell
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-ScriptRequirementRule -ScriptFile "E:\VSCodeRequirement.ps1" -DisplayName "VS Code Requirement" -EnforceSignatureCheck $false -RunAs32Bit $false -RunAsAccount "system" -OperationType "integer" -Operator "equal" -ComparisonValue "0"
$Rules += New-ScriptDetectionRule -ScriptFile "E:\VSCodeDetection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false 
$Rules += New-RegistryRule -ruleType detection -keyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\xyz" -valueName "DisplayName" -operationType string -operator equal -comparisonValue "VSCode"
```
```PowerShell
Invoke-Win32AppUpload -displayName "VS Code" -SourceFile "C:\IntuneApps\vscode\VSCodeSetup-x64-1.93.1.intunewin" -publisher "Microsoft" -description "VS Code (script detection)" -RunAsAccount "system" -Rules $Rules -returnCodes $returnCodes -InstallCommandLine "VSCodeSetup-x64-1.93.1.exe /VERYSILENT /MERGETASKS=!runcode" -UninstallCommandLine "C:\Program Files\Microsoft VS Code\unins000.exe /VERYSILENT" -DeviceRestartBehavior "basedOnReturnCode"
```
3. If successful, the script will return the application information from Intune.
```
Application created successfully.
Application Details:

Assignments           : 
Categories            : 
CreatedDateTime       : 10/7/2024 9:59:54 PM
Description           : VS Code (script detection)
Developer             : 
DisplayName           : VS Code
Id                    : db6c5c99-2282-4e16-95f4-e0332e163902
InformationUrl        : 
IsFeatured            : False
LargeIcon             : Microsoft.Graph.PowerShell.Models.MicrosoftGraphMimeContent
LastModifiedDateTime  : 9/7/2024 9:59:54 PM
Notes                 : 
Owner                 : 
PrivacyInformationUrl : 
Publisher             : Microsoft
PublishingState       : published
AdditionalProperties  : {[@odata.context, https://graph.microsoft.com/v1.0/$metadata#deviceAppManagement/mobileApps/$entity], [@odata.type, #microsoft.graph.win32LobApp], [committedContentVersion, 1], [fileName, IntunePackage.intunewin]…}
```

### Script parameters
The following parameters are required when uploading an Intunewin file via this script sample:

+ SourceFile - This is the path to the Intunewin file
+ Publisher - The publisher of the application
+ Description - Description of the application
+ Rules - The detection and/or requirement rules for the application
+ ReturnCodes - The returncodes for the application

An example of this can be found below:

```PowerShell
# Win32 Application Upload
Invoke-Win32AppUpload -SourceFile "$SourceFile" -publisher "Publisher" -description "Description" -Rules $Rules -returnCodes $ReturnCodes
```
There are other parameters that can be specified, these include:

+ displayName - This can be used to specify the application Name
+ installCommandLine - The complete installation command line for application installation
+ uninstallCommandLine - The complete installation command line for application uninstall
+ runAsAccount - You can configure a Win32 app to be installed in User or System context. User context refers to only a given user. System context refers to all users of a Windows 10 device.
+ deviceRestartBehavior - This setting is used to specify the restart behavior of the device after the app installation is complete. The possible values are 'basedOnReturnCode', 'allow', 'suppress', and 'force'.

An example of this is below:

```PowerShell
# Win32 Application Upload
Invoke-Win32AppUpload -SourceFile "C:\IntuneApps\vscode\VSCodeSetup-x64-1.93.1.intunewin" -displayName "VS Code" -publisher "Microsoft" -description "VS Code" -Rules $Rules -returnCodes $returnCodes -installCommandLine "VSCodeSetup-x64-1.93.1.exe /VERYSILENT /MERGETASKS=!runcode" -uninstallCommandLine "C:\Program Files\Microsoft VS Code\unins000.exe /VERYSILENT" -DeviceRestartBehavior "basedOnReturnCode" -RunAsAccount "system" 
```

### Detection Rules
The following section will provide samples on how to create detection rules and how to add multiple rules.

#### File Rule
To create a file detection rule the following can be used:

```PowerShell
# Defining Intunewin32 detectionRules
$Rules = @()
$Rules += New-FileSystemRule -ruleType detection -operator notConfigured -check32BitOn64System $false -operationType exists -comparisonValue $null -fileOrFolderName "firefox.exe" -path 'C:\Program Files\Mozilla Firefox\firefox.exe'
```

#### MSI Rule
To create an MSI detection rule the following can be used:

```PowerShell
$MSIRule = New-ProductCodeRule -ruleType detection -productCode "{3248F0A8-6813-4B6F-8C3A-4B6C4F512345}" -productVersionOperator equal -productVersion "130.0"
```

If the intunewin file your creating is an MSI you can use the MSI codes stored in the detection.xml file inside the package. This is completed by using the Get-IntuneWinXML function to open the SourceFile and then extracting the detection.xml.

```PowerShell
# Defining Intunewin32 detectionRules
$DetectionXML = Get-IntuneWinXML "$SourceFile" -fileName "detection.xml"

$MSIRule = New-ProductCodeRule -ruleType detection -productVersionOperator equal -productCode $DetectionXML.ApplicationInfo.MsiInfo.MsiProductCode
```

#### Registry Rule
To create a Registry detection rule the following can be used:

```PowerShell
# Defining Intunewin32 detectionRules
New-RegistryRule -ruleType detection -keyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\xyz" -valueName "DisplayName" -operationType string -operator equal -comparisonValue "VSCode"
```

#### PowerShell Script rule
To create PowerShell detection and/or requirement rules, the following example can be used:

```PowerShell
# Defining Intunewin32 script detection and requirement rules
$ScriptDetectionRule = New-ScriptDetectionRule -ScriptFile "E:\VSCodeDetection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false
$ScriptRequirementRule = New-ScriptRequirementRule -ScriptFile "E:\VSCodeRequirement.ps1" -DisplayName "VS Code Requirement" -EnforceSignatureCheck $false -RunAs32Bit $false -RunAsAccount "system" -OperationType "integer" -Operator "equal" -ComparisonValue "0"

# Creating Array for the rules
$DetectionRule = @($ScriptDetectionRule, $ScriptRequirementRule)
```

#### Rule Construction
To create and add multiple detection rules (i.e. File, Registry, MSI) the sample script requires each variable to be passed into an array, once its in an array it can be passed to the JSON object. Example below:

```PowerShell
# Creating Array for detection Rule
$Rules = @()
$Rules += New-ScriptRequirementRule -ScriptFile "E:\VSCodeRequirement.ps1" -DisplayName "VS Code Requirement" -EnforceSignatureCheck $false -RunAs32Bit $false -RunAsAccount "system" -OperationType "integer" -Operator "equal" -ComparisonValue "0"
$Rules += New-ScriptDetectionRule -ScriptFile "E:\VSCodeDetection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false 
$Rules += New-RegistryRule -ruleType detection -keyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\xyz" -valueName "DisplayName" -operationType string -operator equal -comparisonValue "VSCode"

```
### Return Codes
Return codes are used to indicate post-installation behavior. When you add an application via the Intune UI there are five default rules created:

+ ReturnCode = 0 -> Success
+ ReturnCode = 1707 -> Success
+ ReturnCode = 3010 -> Soft Reboot
+ ReturnCode = 1641 -> Hard Reboot
+ ReturnCode = 1618 -> Retry

The sample script requires return codes to be specified. If the default return codes are valid then you can use the following to get all the default return codes:

```PowerShell
$ReturnCodes = Get-DefaultReturnCodes
```

If you want to use the Default return codes but want to add some extra return codes then you can use the following:

```PowerShell
$ReturnCodes = Get-DefaultReturnCodes

$ReturnCodes += New-ReturnCode -returnCode 142 -type softReboot
$ReturnCodes += New-ReturnCode -returnCode 339 -type softReboot
```

If you don't want to include the default return codes, then you need to create an array on the return codes, sample below:

```PowerShell
$ReturnCode1 = New-ReturnCode -returnCode 142 -type softReboot
$ReturnCode2 = New-ReturnCode -returnCode 339 -type softReboot

# Creating Array for ReturnCodes
$ReturnCodes = @($ReturnCode1,$ReturnCode2)
```
Once you have constructed your return codes then they can be passed to the Invoke-Win32AppUpload function.

### Running the script
To run the sample script you can modify the samples below to match the type and conditions you want to upload:

### Sample 1
```PowerShell
# Uploads a .exe Win32 app to Intune using the default return codes and a file system rule.
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-FileSystemRule -ruleType detection -check32BitOn64System $false -operationType exists -operator notConfigured -comparisonValue $null -fileOrFolderName "code.exe" -path 'C:\Program Files\Microsoft VS Code'
Invoke-Win32AppUpload -SourceFile "C:\IntuneApps\vscode\VSCodeSetup-x64-1.93.1.intunewin" -displayName "VS Code" -publisher "Microsoft" -description "VS Code" -Rules $Rules -returnCodes $returnCodes -installCommandLine "VSCodeSetup-x64-1.93.1.exe /VERYSILENT /MERGETASKS=!runcode" -uninstallCommandLine "C:\Program Files\Microsoft VS Code\unins000.exe /VERYSILENT" -DeviceRestartBehavior "basedOnReturnCode" -RunAsAccount "system" 
```

### Sample 2
```PowerShell
# Uploads a .msi Win32 app to Intune using the default return codes and a product code rule.
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-FileSystemRule -ruleType detection -operator notConfigured -check32BitOn64System $false -operationType exists -comparisonValue $null -fileOrFolderName "firefox.exe" -path 'C:\Program Files\Mozilla Firefox\firefox.exe'
$Rules += New-ProductCodeRule detection -productCode "{3248F0A8-6813-4B6F-8C3A-4B6C4F512345}" -productVersionOperator equal -productVersion "130.0"
Invoke-Win32AppUpload -SourceFile "E:\IntuneApps\Firefox\Firefox_Setup_130.0.intunewin" -displayName "Firefox" -publisher "Mozilla" -returnCodes $returnCodes -description "Firefox browser" -Rules $Rules -RunAsAccount "system" -DeviceRestartBehavior "suppress" 
```

### Sample 3
```PowerShell
# Uploads a Win32 app to Intune using the default return codes, a script detection rule, a script requirement rule, and a registry rule, and a registry rule.
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-ScriptRequirementRule -ScriptFile "E:\VSCodeRequirement.ps1" -DisplayName "VS Code Requirement" -EnforceSignatureCheck $false -RunAs32Bit $false -RunAsAccount "system" -OperationType "integer" -Operator "equal" -ComparisonValue "0"
$Rules += New-ScriptDetectionRule -ScriptFile "E:\VSCodeDetection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false 
$Rules += New-RegistryRule -ruleType detection -keyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\xyz" -valueName "DisplayName" -operationType string -operator equal -comparisonValue "VSCode"
Invoke-Win32AppUpload -displayName "VS Code" -SourceFile "C:\IntuneApps\vscode\VSCodeSetup-x64-1.93.1.intunewin" -publisher "Microsoft" -description "VS Code (script detection)" -RunAsAccount "system" -Rules $Rules -returnCodes $returnCodes -InstallCommandLine "VSCodeSetup-x64-1.93.1.exe /VERYSILENT /MERGETASKS=!runcode" -UninstallCommandLine "C:\Program Files\Microsoft VS Code\unins000.exe /VERYSILENT" -DeviceRestartBehavior "basedOnReturnCode"
```
