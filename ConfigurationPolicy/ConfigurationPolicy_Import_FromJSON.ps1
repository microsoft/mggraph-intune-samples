Import-Module Microsoft.Graph.Beta.DeviceManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 

The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 

For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

####################################################

Function Test-JSON() {

    <#
    .SYNOPSIS
    This function is used to test if the JSON passed to a REST Post request is valid
    .DESCRIPTION
    The function tests if the JSON passed to the REST Post is valid
    .EXAMPLE
    Test-JSON -JSON $JSON
    Test if the JSON is valid before calling the Graph REST interface
    .NOTES
    NAME: Test-JSON
    #>
    
    param ( 
        $JSON  
    )
    
    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $validJson = $true  
    }
    
    catch {
        $validJson = $false
        $_.Exception
    }
    
    if (!$validJson) {
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }
}

####################################################

Function Add-ConfigurationPolicy() {

    <#
    .SYNOPSIS
    This function is used to add a Configuration policy using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and adds a Configuration policy
    .EXAMPLE
    Add-ConfigurationPolicy -JSON $JSON
    Adds a Configuration policy in Intune
    .NOTES
    NAME: Add-ConfigurationPolicy
    #>

    [cmdletbinding()]

    param
    (
        $JSON
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies"

    try {

        Test-JSON -JSON $JSON

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

Function Add-ConfigurationPolicySettings() {

    <#
    .SYNOPSIS
    This function is used to add Configuration policy settings using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and adds Configuration policy settings
    .EXAMPLE
    Add-ConfigurationPolicySettings -JSON $JSON -policyid $policyid
    Adds Configuration policy settings in Intune
    .NOTES
    NAME: Add-ConfigurationPolicySettings
    #>

    [cmdletbinding()]

    param
    (
        $JSON,
        $policyid
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/configurationPolicies('$policyid')/settings"

    try {

        Test-JSON -JSON $JSON

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

$ImportPath = Read-Host -Prompt "Please specify a path to a JSON file to import data from e.g. C:\IntuneOutput\Policies\policy.json"

# Replacing quotes for Test-Path
$ImportPath = $ImportPath.replace('"', '')

if (!(Test-Path "$ImportPath")) {

    Write-Host "Import Path for JSON file doesn't exist..." -ForegroundColor Red
    Write-Host "Script can't continue..." -ForegroundColor Red
    Write-Host
    break

}

####################################################

# Importing JSON file
$JSON_Data = Get-Content -Path "$ImportPath" -Raw

# Testing if valid JSON
Test-JSON -JSON $JSON_Data

$JSON_Convert = $JSON_Data | ConvertFrom-Json

$DisplayName = $JSON_Convert.name

Write-Host "Configuration Policy '$DisplayName' Found..." -ForegroundColor Yellow
Write-Host

####################################################

# Creating policy body for import
$PolicyBody = New-Object -TypeName PSObject

Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'name' -Value $JSON_Convert.name
Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'description' -Value $JSON_Convert.description
Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'platforms' -Value $JSON_Convert.platforms
Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'technologies' -Value $JSON_Convert.technologies

# Checking if policy has a templateId associated
if ($JSON_Convert.templateReference.templateId) {

    Write-Host "Template reference found" -f Cyan
    
    $PolicyTemplateReference = New-Object -TypeName PSObject
    Add-Member -InputObject $PolicyTemplateReference -MemberType 'NoteProperty' -Name 'templateId' -Value $JSON_Convert.templateReference.templateId
    Add-Member -InputObject $PolicyBody -MemberType 'NoteProperty' -Name 'templateReference' -Value $PolicyTemplateReference

}

$PolicyBody_JSON = $PolicyBody | ConvertTo-Json -Depth 10

Write-Host "Adding Configuration Policy '$DisplayName'" -ForegroundColor Yellow

####################################################

# Adding Configuration policy
$CreateResult = Add-ConfigurationPolicy -JSON $PolicyBody_JSON

Write-Host "Configuration policy created successfully" -ForegroundColor Green
Write-Host "Policy ID:" $CreateResult.id -ForegroundColor Cyan
Write-Host

####################################################

# Adding Settings to the policy
if ($JSON_Convert.settings) {

    # Get policy id from results
    $policy_id = $CreateResult.id

    Write-Host "Adding settings to Configuration Policy..." -ForegroundColor Yellow

    foreach ($Setting in $JSON_Convert.settings) {

        $Setting_JSON = $Setting | ConvertTo-Json -Depth 20

        Write-Host "Adding setting..."

        Add-ConfigurationPolicySettings -JSON $Setting_JSON -policyid $policy_id

    }

    Write-Host
    Write-Host "Settings added successfully" -ForegroundColor Green

}

Write-Host
Write-Host "Configuration Policy '$DisplayName' imported successfully!" -ForegroundColor Green
