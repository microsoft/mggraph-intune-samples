Import-Module Microsoft.Graph.DeviceManagement

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

$DCPs = Get-MgDeviceManagementDeviceConfiguration

write-host

foreach ($DCP in $DCPs) {

    write-host "Device Configuration Policy:"$DCP.displayName -f Yellow
    write-host
    $DCP

    $id = $DCP.id

    $DCPA = Get-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $id
    write-host "Getting Configuration Policy assignment..." -f Cyan
    if ($DCPA) {
        if ($DCPA.count -gt 1) {
            foreach ($group in $DCPA) {
                $parts = $group.Id -split "_"
                $gid = $parts[1]
            (Get-MgGroup -GroupId $gid).displayName

            }

        }

        else {
            $parts = $DCPA.Id -split "_"
            $gid = $parts[1]
            (Get-MgGroup -GroupId $gid).displayName
        }
    }
    else {
        Write-Host "No assignments found."
    }
    Write-Host
}