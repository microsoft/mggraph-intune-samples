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

Function Add-ConfigurationPolicyAssignment() {

    <#
.SYNOPSIS
This function is used to add a Configuration policy assignment using the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and adds a Configuration policy assignment
.EXAMPLE
Add-ConfigurationPolicyAssignment -ConfigurationPolicyId $ConfigurationPolicyId -TargetGroupId $TargetGroupId
Adds a Configuration policy assignment in Intune
.NOTES
NAME: Add-ConfigurationPolicyAssignment
#>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ConfigurationPolicyId,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $TargetGroupId,

        [parameter(Mandatory = $false)]
        [ValidateSet("Include", "Exclude")]
        $AssignmentType = "Include"
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$ConfigurationPolicyId')/assign"

    try {

        if ($AssignmentType -eq "Exclude") {

            $TargetGroup = @{
                '@odata.type' = '#microsoft.graph.exclusionGroupAssignmentTarget'
                groupId       = $TargetGroupId
            }

        }

        else {

            $TargetGroup = @{
                '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
                groupId       = $TargetGroupId
            }

        }

        $Assignment = @{
            assignments = @(
                @{
                    target = $TargetGroup
                }
            )
        }

        $JSON = $Assignment | ConvertTo-Json -Depth 3

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON

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

# Setting application AAD Group to assign Policy

$AADGroup = Read-Host -Prompt "Enter the Azure AD Group name or ID where policies will be assigned"

# Try to get group by ID first, then by display name
try {
    $TargetGroup = Get-MgGroup -GroupId "$AADGroup" -ErrorAction SilentlyContinue
}
catch {
    # If getting by ID fails, try searching by display name
    $TargetGroup = Get-MgGroup -Filter "displayName eq '$AADGroup'" -ErrorAction SilentlyContinue
}

if ($null -eq $TargetGroup -or $TargetGroup -eq "") {

    Write-Host "AAD Group - '$AADGroup' doesn't exist, please specify a valid AAD Group..." -ForegroundColor Red
    Write-Host
    exit

}

Write-Host "Found AAD Group:" $TargetGroup.displayName -ForegroundColor Green
Write-Host

####################################################

$PolicyId = Read-Host -Prompt "Enter the Configuration Policy ID to assign"

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

        Write-Host "Configuration Policy found:" $Policy.name -ForegroundColor Yellow
        Write-Host

        # Prompt for assignment type
        Write-Host "Assignment Type:" -ForegroundColor Yellow
        Write-Host "1. Include (Assign policy to group members)" -ForegroundColor Cyan
        Write-Host "2. Exclude (Exclude group members from policy)" -ForegroundColor Cyan
        $AssignmentChoice = Read-Host -Prompt "Select assignment type (1 or 2, default is 1)"

        $AssignmentType = "Include"
        if ($AssignmentChoice -eq "2") {
            $AssignmentType = "Exclude"
        }

        Write-Host
        Write-Host "Assigning Configuration Policy to group..." -ForegroundColor Yellow

        Add-ConfigurationPolicyAssignment -ConfigurationPolicyId $PolicyId -TargetGroupId $TargetGroup.id -AssignmentType $AssignmentType

        if ($AssignmentType -eq "Exclude") {
            Write-Host "Configuration Policy '$($Policy.name)' excluded from group '$($TargetGroup.displayName)' successfully" -ForegroundColor Green
        }
        else {
            Write-Host "Configuration Policy '$($Policy.name)' assigned to group '$($TargetGroup.displayName)' successfully" -ForegroundColor Green
        }

    }

}
catch {

    Write-Host "Configuration Policy with ID '$PolicyId' doesn't exist or couldn't be retrieved..." -ForegroundColor Red
    Write-Host

}
