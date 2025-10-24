Import-Module Microsoft.Graph.Beta.DeviceManagement
Import-Module Microsoft.Graph.Groups

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

Function Get-ConfigurationPolicyAssignments() {

    <#
.SYNOPSIS
This function is used to get Configuration policy assignments from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets a Configuration policy assignments
.EXAMPLE
Get-ConfigurationPolicyAssignments -ConfigurationPolicyId $ConfigurationPolicyId
Returns any Configuration policy assignments configured in Intune
.NOTES
NAME: Get-ConfigurationPolicyAssignments
#>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ConfigurationPolicyId
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$ConfigurationPolicyId')/assignments"

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri -Method Get).Value

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

$PolicyId = Read-Host -Prompt "Enter the Configuration Policy ID to get assignments"

if ($PolicyId -eq "" -or $null -eq $PolicyId) {

    Write-Host "No Configuration Policy ID specified..." -ForegroundColor Red
    Write-Host
    exit

}

# Verify the policy exists
$graphApiVersion = "beta"
$Resource = "deviceManagement/configurationPolicies('$PolicyId')"
$uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

try {
    $Policy = Invoke-MgGraphRequest -Uri $uri -Method Get

    if ($Policy) {

        Write-Host "Configuration Policy:" $Policy.name -ForegroundColor Yellow
        Write-Host

        $Assignments = Get-ConfigurationPolicyAssignments -ConfigurationPolicyId $PolicyId

        if ($Assignments) {

            Write-Host "Assignments found:" -ForegroundColor Cyan
            Write-Host

            foreach ($Assignment in $Assignments) {

                if ($Assignment.target.'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') {

                    $GroupId = $Assignment.target.groupId
                    
                    try {
                        $Group = Get-MgGroup -GroupId $GroupId
                        Write-Host "  - Include: $($Group.displayName)" -ForegroundColor Green
                        Write-Host "    Group ID: $GroupId"
                    }
                    catch {
                        Write-Host "  - Include: Group (Unable to retrieve name)" -ForegroundColor Green
                        Write-Host "    Group ID: $GroupId"
                    }

                }
                elseif ($Assignment.target.'@odata.type' -eq '#microsoft.graph.exclusionGroupAssignmentTarget') {

                    $GroupId = $Assignment.target.groupId
                    
                    try {
                        $Group = Get-MgGroup -GroupId $GroupId
                        Write-Host "  - Exclude: $($Group.displayName)" -ForegroundColor Red
                        Write-Host "    Group ID: $GroupId"
                    }
                    catch {
                        Write-Host "  - Exclude: Group (Unable to retrieve name)" -ForegroundColor Red
                        Write-Host "    Group ID: $GroupId"
                    }

                }
                elseif ($Assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {

                    Write-Host "  - All Users" -ForegroundColor Green

                }
                elseif ($Assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {

                    Write-Host "  - All Devices" -ForegroundColor Green

                }

                Write-Host

            }

        }
        else {

            Write-Host "No assignments found for this Configuration Policy" -ForegroundColor Yellow
            Write-Host

        }

    }

}
catch {

    Write-Host "Configuration Policy with ID '$PolicyId' doesn't exist or couldn't be retrieved..." -ForegroundColor Red
    Write-Host

}
