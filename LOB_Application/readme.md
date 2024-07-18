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
+ Dependent PowerShell module (Microsoft.Graph)
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
