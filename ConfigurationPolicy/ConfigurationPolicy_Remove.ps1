Import-Module Microsoft.Graph.Beta.DeviceManagement

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

#endregion

####################################################

Function Remove-ConfigurationPolicy() {

    <#
.SYNOPSIS
This function is used to remove a Configuration policy from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and removes a Configuration policy
.EXAMPLE
Remove-ConfigurationPolicy -policyId $policyId
Removes a Configuration policy configured in Intune
.NOTES
NAME: Remove-ConfigurationPolicy
#>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$policyId
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$policyId')"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Delete

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

$PolicyId = Read-Host -Prompt "Please specify the Configuration Policy ID to remove"

if ($PolicyId) {

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$PolicyId')"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

    try {
        $Policy = Invoke-MgGraphRequest -Uri $uri -Method Get

        if ($Policy) {
            Write-Host "Configuration Policy found:" $Policy.name -ForegroundColor Yellow
            Write-Host
            Write-Host "Are you sure you want to remove this Configuration Policy? Y or N?" -ForegroundColor Yellow
            $Confirm = read-host

            if ($Confirm -eq "y" -or $Confirm -eq "Y") {
                Remove-ConfigurationPolicy -policyId $PolicyId
                Write-Host "Configuration Policy" $Policy.name "removed successfully" -ForegroundColor Green
            }
            else {
                Write-Host "Removal of Configuration Policy cancelled..." -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "Configuration Policy with ID $PolicyId doesn't exist or couldn't be retrieved..." -ForegroundColor Red
        Write-Host
    }

}
else {

    Write-Host "No Configuration Policy ID specified..." -ForegroundColor Red
    Write-Host

}
