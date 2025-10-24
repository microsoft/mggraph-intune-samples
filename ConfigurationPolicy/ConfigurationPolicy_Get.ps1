Import-Module Microsoft.Graph.Beta.DeviceManagement

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

#endregion

####################################################

Function Get-ConfigurationPolicy() {

    <#
.SYNOPSIS
This function is used to get Configuration policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Configuration policies
.EXAMPLE
Get-ConfigurationPolicy
Returns any Configuration policies configured in Intune
Get-ConfigurationPolicy -Platform windows10
Returns any Windows 10 Configuration policies configured in Intune
Get-ConfigurationPolicy -Platform macOS
Returns any MacOS Configuration policies configured in Intune
Get-ConfigurationPolicy -Technology windows365
Returns any Windows 365 Configuration policies configured in Intune
.NOTES
NAME: Get-ConfigurationPolicy
#>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $false)]
        [ValidateSet("windows10", "macOS", "iOS", "android")]
        [ValidateNotNullOrEmpty()]
        [string]$Platform,

        [parameter(Mandatory = $false)]
        [ValidateSet("mdm", "windows365", "microsoftSense", "endpointPrivilegeManagement", "configManager", "appleRemoteManagement", "exchangeOnline", "mobileApplicationManagement", "linuxMdm", "extensibility", "enrollment", "windowsOsRecovery", "android")]
        [ValidateNotNullOrEmpty()]
        [string]$Technology
    )

    $graphApiVersion = "beta"

    if ($Platform -and $Technology) {
        
        $Resource = "deviceManagement/configurationPolicies?`$filter=platforms has '$Platform' and technologies has '$Technology'"

    }
    elseif ($Platform) {
        
        $Resource = "deviceManagement/configurationPolicies?`$filter=platforms has '$Platform'"

    }
    elseif ($Technology) {
        
        $Resource = "deviceManagement/configurationPolicies?`$filter=technologies has '$Technology'"

    }
    else {

        $Resource = "deviceManagement/configurationPolicies"

    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri  -Method Get).Value

    }

    catch {

        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break

    }

}

####################################################

$Policies = Get-ConfigurationPolicy

write-host

foreach ($Policy in $Policies) {

    write-host "Configuration Policy:" $Policy.name -f Yellow
    write-host "  ID:" $Policy.id
    write-host "  Description:" $Policy.description
    write-host "  Platforms:" $Policy.platforms
    write-host "  Technologies:" $Policy.technologies
    write-host "  Created:" $Policy.createdDateTime
    write-host "  Last Modified:" $Policy.lastModifiedDateTime

    if ($Policy.templateReference.templateId) {
        write-host "  Template ID:" $Policy.templateReference.templateId -f Cyan
    }

    Write-Host

}
