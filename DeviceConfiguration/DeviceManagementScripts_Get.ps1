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


$PSScripts = Get-MgBetaDeviceManagementScript

if ($PSScripts) {

    write-host "-------------------------------------------------------------------"
    Write-Host

    $PSScripts | ForEach-Object {

        $ScriptId = $_.id
        $DisplayName = $_.displayName

        Write-Host "PowerShell Script: $DisplayName..." -ForegroundColor Yellow

        $_

        write-host "Device Management Scripts - Assignments" -f Cyan

        $Assignments = Get-MgBetaDeviceManagementScriptAssignment -DeviceManagementScriptId $_.Id

        if ($Assignments) {

            foreach ($Group in $Assignments) {
                $parts = $group.Id -split ":"
                $gid = $parts[1]
            (Get-MgGroup -GroupId $gid).displayName

            }

            Write-Host

        }

        else {

            Write-Host "No assignments set for this policy..." -ForegroundColor Red
            Write-Host

        }

        $Script = Get-MgBetaDeviceManagementScript -DeviceManagementScriptId $ScriptId

        $ScriptContent = $Script.scriptContent

        Write-Host "Script Content:" -ForegroundColor Cyan

        [System.Text.Encoding]::UTF8.GetString($script.ScriptContent)
        Write-Host
        write-host "-------------------------------------------------------------------"
        Write-Host

    }

}

else {

    Write-Host
    Write-Host "No PowerShell scripts have been added to the service..." -ForegroundColor Red
    Write-Host

}
