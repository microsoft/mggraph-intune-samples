<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

Import-Module Microsoft.Graph.Authentication

<#
.SYNOPSIS
This function analyzes a provided PowerShell script to find the least-privileged Graph permissions required for the Graph SDK cmdlets included in the script.

.DESCRIPTION
This function reads a provided PowerShell script and searches for Graph SDK cmdlets that require Graph permissions. It then uses the Find-MgGraphCommand function to find the permissions required for each cmdlet and identifies the least-privileged permissions required for the script. The script outputs the script name, cmdlets found, permissions required, least-privileged permissions, and cmdlets that were not found.

.NOTES
1. This script requires the Microsoft.Graph.Authentication module to be installed. You can install the module from the PowerShell Gallery by running the following command:
Install-Module -Name Microsoft.Graph.Authentication

2. This script does NOT check permissions for Graph calls manually made using Invoke-MgGraphRequest. You should manually review these calls to ensure they have the appropriate permissions.

3. If a permission is not found for a cmdlet, the cmdlet will be added to the CmdletsNotFound array in the returned object.

.PARAMETER scriptPath
The path to the PowerShell script file to analyze.

.EXAMPLE
# Analyze a specific script file
Get-ScriptPermissions -ScriptPath ".\ManagedAppPolicy_Wipe.ps1"

.EXAMPLE
# Analyze all script files in a directory
Get-ChildItem -Path "C:\mggraph-intune-samples" -Recurse -Filter *.ps1 | ForEach-Object {
    Get-ScriptPermissions -ScriptPath $_.FullName
}
#>
function Get-ScriptPermissions {
    param (
        [string]$ScriptPath
    )

    if (-not (Test-Path -Path $scriptPath -PathType Leaf)) {
        Write-Host "The specified script path does not exist or is not a file."
        return
    }

    # Get the script name from the script path
    $scriptName = Split-Path -Path $scriptPath -Leaf

    # Read the content of the script file
    $scriptContent = Get-Content -Path $scriptPath

    # Use Select-String to find all lines containing the string "-Mg"
    $foundMatches = $scriptContent | Select-String -Pattern "-Mg", "-MgBeta" -AllMatches

    # Extract cmdlets from the matched lines
    $cmdlets = foreach ($match in $foundMatches) {
        if ($match.Line -match "\b(\w+-Mg\w*)\b") {
            $matches
        }
    }

    # Remove duplicates from the cmdlets
    $cmdlets = $cmdlets.Values | Sort-Object -Unique

    # Create a custom object to store the script name, cmdlets found, permissions, least privilege permissions, and the cmdlets that were not found using the Find-MgGraphCommand function
    $ScriptInformation = New-Object PSObject -Property @{
        ScriptName                   = $scriptName
        CmdletsDetected              = @()
        LeastPrivilegedPermissions   = @()
        CmdletsNotFound              = @()
        'Invoke-MgGraphRequestFound' = $false
    }

    # Loop through each cmdlet and find the permissions and least privilege permissions
    foreach ($cmdlet in $cmdlets) {

        # Check if the cmdlet is Invoke-MgGraphRequest
        # If it is, set the Invoke-MgGraphRequestFound property to true
        if ($cmdlet.ToLower() -eq "invoke-mggraphrequest" ) {
            $ScriptInformation.'Invoke-MgGraphRequestFound' = $true
        }
        # Check if the cmdlet is Connect-MgGraph or Invoke-MgGraphRequest
        # If it is, skip the Find-MgGraphCommand function
        elseif ($cmdlet.ToLower -ne "invoke-mggraphrequest" -and $cmdlet.ToLower -ne "connect-mggraph") {
            try {
                # Find the permissions for the cmdlet
                $permissions = Find-MgGraphCommand -Command $cmdlet -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Permissions
                if ($permissions) {
                    # Add the cmdlet to the CmdletsDetected array
                    $ScriptInformation.CmdletsDetected += $cmdlet

                    # Find the least privilege permission for the cmdlet
                    $leastPriv = $permissions | Where-Object { $_.IsLeastPrivilege -eq $true } | Select-Object -First 1
                    
                    # Add the least privilege permission to the LeastPrivilegedPermissions array
                    if ($ScriptInformation.LeastPrivilegedPermissions -notcontains $leastPriv.Name) {
                        $ScriptInformation.LeastPrivilegedPermissions += $leastPriv.Name
                    }
                }
                # If the permissions are not found for the cmdlet, add the cmdlet to the CmdletsNotFound array
                else {
                    $ScriptInformation.CmdletsNotFound += $cmdlet
                }           
            }
            catch {
                Write-Host "Error: $_"
                continue
            }
        }
    }
    # Return the custom object with the script name, cmdlets found, permissions, least privilege permissions, and the cmdlets that were not found
    return $ScriptInformation
}
