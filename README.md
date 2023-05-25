---
page_type: sample
products:
- ms-graph
languages:
- powershell
extensions:
  contentType: samples
  technologies:
  - Microsoft Graph 
  services:
  - Intune
noDependencies: true
---

# MGGraph Intune Samples

This repository of sample scripts demonstrates how to access Intune service resources.  There are many ways to access the Microsoft Graph through scripting languages and the samples in this repo provide examples that you are free to utilize.

Documentation for Intune and Microsoft Graph is found here [Intune Graph Documentation](https://docs.microsoft.com/en-us/graph/api/resources/intune-graph-overview?view=graph-rest-1.0).

These samples demonstrate typical Intune administrator or Microsoft partner actions for managing Intune resources.

The scripts are licensed "as-is." under the MIT License.

#### Disclaimer
Some script samples retrieve information from your Intune tenant, and others create, delete or update data in your Intune tenant.  Understand the impact of each sample script prior to running it; samples should be run using a non-production or "test" tenant account. 

## Using the Intune Graph API
The Intune Graph API enables programmatic access to your Intune tenant information. The API performs the same Intune operations as those available through the Intune portal. The Intune Portal utilizes the beta version of the Microsoft Graph (e.g. https://graph.microsoft.com/beta/<namespace>). The scripts in this repository will be using the v1.0 version unless it is unavailable. 

Intune provides data into the Microsoft Graph in the same way as other cloud services do, with rich entity information and relationship navigation.  Use Microsoft Graph to combine information from other services and Intune to build rich cross-service applications for IT professionals or end users. Natively in Powershell you can pipe configurations from one cmdlet, from a specific service into another. This allows solutions to be built that are intuitive and native to the API.   

## Prerequisites
Use of these samples requires the following:

* An Intune tenant which supports the Azure Portal with a production or trial license (https://docs.microsoft.com/en-us/intune-azure/introduction/what-is-microsoft-intune)
* Using the Microsoft Graph APIs to configure Intune controls and policies requires an Intune license.
* An account with permissions to administer the Intune Service
* PowerShell v5.0 or later on Windows 10 x64 (PowerShell v4.0 is a minimum requirement for the scripts to function correctly)
* Note: For PowerShell 4.0 you will require the [PowershellGet Module for PS 4.0](https://www.microsoft.com/en-us/download/details.aspx?id=51451) to enable the usage of the Install-Module functionality
* First time usage of these scripts requires a Global Administrator of the Tenant to accept the permissions of the application (grant consent).
* The Microsoft Graph Powershell SDK module installed (https://github.com/microsoftgraph/msgraph-sdk-powershell)

## Getting Started
After the prerequisites are installed or met, perform the following steps to use these scripts:

#### 1. Script usage

1. Download the contents of the repository to your local Windows machine
* Extract the files to a local folder (e.g. C:\IntuneGraphSamples)
* Run PowerShell x64 from the start menu
* Browse to the directory (e.g. cd C:\IntuneGraphSamples)
* Either connect using Connect-MgGraph or update the script to include code to call Connect-MgGraph: https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0
* For each Folder in the local repository you can browse to that directory and then run the script of your choice
* Example Application script usage:
  * To use the Manage Applications scripts, from C:\IntuneGraphSamples, run "cd .\Applications\"
  * Once in the folder run .\Application_MDM_Get.ps1 to get all MDM added applications
  This sequence of steps can be used for each folder....

#### 2. Authentication with Microsoft Graph
To run any of the Intune-based commands in the Microsoft Graph PowerShell SDK, you'll first need to authenticate against your tenant. If you haven't already installed and set up the SDK, see the following links for guidance:
* [Installation](https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0)
* [Get Started](https://learn.microsoft.com/en-us/graph/powershell/get-started)

The Microsoft Graph PowerShell SDK supports two types of authentication: 
* Delegated access - an app acting on behalf of a signed-in user (interactive logon).
* App-only access - an app acting with its own identity (unattended scenarios).

For guidance on authenticating using either method, review the following documentation:
* [Authentication commands](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0)
* [Use app-only authentication with the Microsoft Graph PowerShell SDK](https://learn.microsoft.com/en-us/powershell/microsoftgraph/app-only?toc=%2Fgraph%2Ftoc.json&view=graph-powershell-1.0&tabs=azure-portal)

Each API in the Microsoft Graph is protected by one or more permission scopes. Use the Connect-MgGraph command to sign in with the required scopes. You'll need to sign in with an admin account to consent to the scopes that the Microsoft Graph PowerShell SDK requires if they haven't been granted previously.

**Important**: Connecting with the minmium required permissions for each example scenario is out of scope for the sample scripts provided in this repository. Within each script, you will see an authentication region where you will need to specify your authentication details and permission scope requirements if you are not already authenticated into the service.

For more information and to learn how to use the Find-MgGraphCommand to identify the minimum required permissions each command requires, see here:
[Determine required permission scopes](https://learn.microsoft.com/en-us/powershell/microsoftgraph/get-started?view=graph-powershell-1.0#authentication)

## Contributing

If you'd like to contribute to this sample, see CONTRIBUTING.MD.

This project has adopted the Microsoft Open Source Code of Conduct. For more information see the Code of Conduct FAQ or contact opencode@microsoft.com with any additional questions or comments.

## Questions and comments

We'd love to get your feedback about these Intune PowerShell samples. You can send your questions and suggestions to us in the Issues section of this repository.

Your feedback is important to us. Connect with us on Stack Overflow. Tag your questions with [MicrosoftGraph] and [Intune].


## Additional resources
* [Microsoft Graph](https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0)
* [Microsoft Graph API documentation](https://developer.microsoft.com/en-us/graph/docs)
* [Microsoft Graph Portal](https://developer.microsoft.com/en-us/graph/graph-explorer)
* [Microsoft code samples](https://developer.microsoft.com/en-us/graph/code-samples-and-sdks)
* [Intune Graph Documentation](https://docs.microsoft.com/en-us/graph/api/resources/intune-graph-overview?view=graph-rest-1.0)

## Copyright
Copyright (c) 2023 Microsoft. All rights reserved.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.
