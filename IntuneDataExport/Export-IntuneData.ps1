<#
.COPYRIGHT
Copyright (c) Microsoft Corporation. All rights reserved. Licensed under the MIT license.
See LICENSE in the project root for license information.
#>

####################################################

param(
    [Parameter(HelpMessage = "Entra ID Username", Mandatory = $true)]
    [string]
    $Username,
    [Parameter(HelpMessage = "User principal name to export data for", Mandatory = $true)]
    [string]
    $Upn,
    [Parameter(HelpMessage = "Include EntraID data in export")]
    [switch]
    $IncludeEntraID,
    [Parameter(HelpMessage = "Include data For Non Entra ID Upn in export")]
    [switch]
    $IncludeNonEntraIDUpn,
    [Parameter(HelpMessage = "Include all data in the export")]
    [switch]
    $All,
    [Parameter(HelpMessage = "Path to export data to", Mandatory = $true)]
    [string]
    $OutputPath,
    [Parameter(HelpMessage = "Format to export data in")]
    [ValidateSet("JSON", "CSV", "XML")]
    $ExportFormat = "JSON",
    [Parameter(DontShow = $true)]
    [string]
    $MsGraphVersion = "beta",
    [Parameter(DontShow = $true)]
    [string]
    $MsGraphHost = "graph.microsoft.com",
    [Parameter(DontShow = $true)]
    [string]
    $ConfigurationFile
)

####################################################

function Log-Verbose($message) {
    Write-Verbose "[$([System.DateTime]::Now)] - $message"
}

####################################################

function Log-Info ($message) {
    Write-Information "INFO: [$([System.DateTime]::Now)] - $message" -InformationAction Continue
}

####################################################

function Log-Warning ($message) {
    Write-Warning "[$([System.DateTime]::Now)] - $message" -WarningAction Continue  
}

####################################################

function Log-Error ($message) {
    Write-Error "[$([System.DateTime]::Now)] - $message" -WarningAction Continue
}

####################################################

function Log-FatalError($message) {
    Write-Error "[$([System.DateTime]::Now)] - $message" -WarningAction Continue
    Write-Error "Script will now exit"
    exit
}

####################################################

function Test-GraphSession {
    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Test-GraphSession
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Test-GraphSession
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory = $true)]
        $User
    )
    
    Write-Host "Checking for Microsoft.Graph and Microsoft.Graph.Beta modules..."
    try {
        $GraphBetaModule = Get-Module -Name "Microsoft.Graph.Beta" -ListAvailable
        $GraphModule = Get-Module -Name "Microsoft.Graph" -ListAvailable
        $Scopes = @("User.Read.All", "DeviceManagementManagedDevices.Read.All", "DeviceManagementConfiguration.Read.All", "DeviceManagementApps.Read.All", "DeviceManagementServiceConfig.Read.All")
    
        if ($null -eq $GraphModule -and $null -eq $GraphBetaModule) {
            write-host
            write-host "Microsoft Graph PowerShell SDK module not installed..." -f Red
            write-host "Install by running 'Install-Module Microsoft.Graph.Beta' or 'Install-Module Microsoft.Graph.Beta' from an elevated PowerShell prompt" -f Yellow
            write-host "Script can't continue..." -f Red
            write-host
            exit
        }
        elseif ($null -ne $GraphModule -and $null -ne $GraphBetaModule) {
            write-host "Microsoft Graph PowerShell SDK module found..." -f Green
            #Check if user is already logged in
            $User = $User.ToLowerInvariant()
            $SessionDetails = Get-MgContext

            if ($null -eq $SessionDetails) {
                write-host
                write-host "User not logged in..." -f Red
                write-host "Please login using 'Connect-MgGraph' prior to running this script. See here for more information: https://learn.microsoft.com/en-us/powershell/microsoftgraph/authentication-commands?view=graph-powershell-1.0" -f Yellow
                write-host "Script can't continue..." -f Red
                write-host
                exit
            }
            foreach ($Permission in $Scopes) {
                if ($SessionDetails.Scopes -notcontains $Permission) {
                    write-host
                    write-host "User not logged in with required permissions..." -f Red
                    write-host "Please login using 'Connect-MgGraph' with the following scopes: User.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementConfiguration.Read.All, DeviceManagementApps.Read.All, DeviceManagementServiceConfig.Read.All" -f Yellow
                    write-host "Script can't continue..." -f Red
                    write-host
                    exit
                }
            }
            Write-Host
            write-host "User already logged in..." -f Green
            write-host
            Write-Host "Required permissions found..." -f Green
            write-host
        }
    }
    catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    }
    
}
    
####################################################

function Get-MsGraphObject($Path, [switch]$IgnoreNotFound) {
    $FullUri = "https://$MsGraphHost/$MsGraphVersion/$Path"
    Log-Verbose "GET $FullUri"

    try {
        return  Invoke-MgGraphRequest -Method GET -Uri $FullUri 
    } 
    catch {
        $Response = $_.Exception.Response
        if ($IgnoreNotFound -and $Response.StatusCode -eq "NotFound") {
            return $null
        }
        Log-Error "Request Failed: $($_.Exception.Message)`n$($_.ErrorDetails)"
        Log-Error "Request URL: $FullUri"
        Log-Error "Response Content:`n$_"
        break
    }
}

####################################################

function Get-MsGraphCollection($Path) {
    $FullUri = "https://$MsGraphHost/$MsGraphVersion/$Path"
    $Collection = @()
    $NextLink = $FullUri

    do {
        try {
            Log-Verbose "GET $NextLink"
            $Result = Invoke-MgGraphRequest -Method Get -Uri $NextLink 
            $Collection += $Result.value
            $NextLink = $Result.'@odata.nextLink'
        } 
        catch {
            Log-Error "Request Failed: $($_.Exception.Message)`n$($_.ErrorDetails)"
            Log-Error "Request URL: $NextLink"
            Log-Error "Response Content:`n$_"
            break
        }
    } while ($NextLink -ne $null)
    Log-Verbose "Got $($Collection.Count) object(s)"

    return $Collection
}

####################################################

function Post-MsGraphObject($Path, $RequestBody) {
    $FullUri = "https://$MsGraphHost/$MsGraphVersion/$Path"

    try {
        Log-Verbose "POST $Fulluri"

        $RequestBodyJson = $RequestBody | ConvertTo-Json

        Log-Verbose "Request Body Json:"
        Log-Verbose $RequestBodyJson

        $Result = Invoke-MgGraphRequest -Method Post -Uri $FullUri -Body $RequestBodyJson
        return $Result
    } 
    catch {
        Log-Error "Request Failed: $($_.Exception.Message)`n$($_.ErrorDetails)"
        Log-Error "Request URL: $NextLink"
        Log-Error "Response Content:`n$_"
        break
    }
}

####################################################

function Get-User {
    Log-Info "Getting Entra ID User data for UPN $UPN"
    return Get-MsGraphObject "users/$Upn" -IgnoreNotFound
}

####################################################

#region Intune Functions

function Test-IntuneUser {
    Log-Info "Checking if User $UPN is a Microsoft Intune user"

    try {
        Invoke-MgGraphRequest -Method Get -Uri "https://$MsGraphHost/$MsGraphVersion/users/$($UserId)/managedDevices" 
    } 
    catch {
        $Response = $_.Exception.Response
        if ($Response.StatusCode -eq "NotFound") {
            return $false
        }
    }

    return $true
}

####################################################

function Get-GroupMemberships {
    Log-Info "Getting Entra ID Group memberships for User $UPN"
    return Get-MsGraphCollection "users/$Upn/memberOf/microsoft.graph.group"
}

####################################################

function Get-RegisteredDevices {
    Log-Info "Getting Entra ID Registered Devices for User $UPN"
    return Get-MsGraphCollection "users/$Upn/registeredDevices"
}

####################################################

function Get-ManagedDevices {
    Log-Info "Getting managed devices for User $UPN"
    
    $DeviceIds = @(Get-MsGraphCollection "users/$UserId/managedDevices?`$select=id" | Select-Object -ExpandProperty id)

    $Devices = @()

    foreach ($DeviceId in $DeviceIds) {
        $Device = Get-MsGraphObject "deviceManagement/managedDevices/$($DeviceId)?`$expand=detectedApps"
        $Category = Get-MsGraphObject "deviceManagement/managedDevices/$($Device.id)/deviceCategory"
        Add-Member -InputObject $Device "deviceCategory" $Category

        $DeviceConfigurationStates = Get-MsGraphCollection "deviceManagement/managedDevices/$($Device.id)/deviceConfigurationStates"

        $ApplicableDeviceConfigurationStates = @($DeviceConfigurationStates | Where-Object { $_.state -ne "notApplicable" })

        foreach ($ApplicableDeviceConfigurationState in $ApplicableDeviceConfigurationStates) {
            $ApplicableDeviceConfigurationState.settingStates = @(Get-MsGraphCollection "deviceManagement/managedDevices/$($Device.id)/deviceConfigurationStates/$($ApplicableDeviceConfigurationState.id)/settingStates")
        }

        Add-Member NoteProperty -InputObject $Device -Name "deviceConfigurationStates" -Value @()
        foreach ($dcs in $ApplicableDeviceConfigurationStates) {
            $Device.deviceConfigurationStates += $dcs
        }
        $DeviceCompliancePolicyStates = Get-MsGraphCollection "deviceManagement/managedDevices/$($Device.id)/deviceCompliancePolicyStates"

        $ApplicableDeviceCompliancePolicyStates = @($DeviceCompliancePolicyStates | Where-Object { $_.state -ne "notApplicable" })
        foreach ($ApplicableDeviceCompliancePolicyState in $ApplicableDeviceCompliancePolicyStates) {
            $ApplicableDeviceCompliancePolicyState.settingStates = @(Get-MsGraphCollection "deviceManagement/managedDevices/$($Device.id)/deviceCompliancePolicyStates/$($ApplicableDeviceCompliancePolicyState.id)/settingStates")
        }

        Add-Member NoteProperty -InputObject $Device -Name "deviceCompliancePolicyStates" -Value @()
        foreach ($dcs in $ApplicableDeviceCompliancePolicyStates) {
            $Device.deviceCompliancePolicyStates += $dcs
        }
        $DeviceWithHardwareInfo = Get-MsGraphObject "deviceManagement/managedDevices/$($Device.id)/?`$select=id,hardwareInformation"
        $Device.hardwareInformation = $DeviceWithHardwareInfo.hardwareInformation
        $Devices += $Device
    }
    return $Devices
}

####################################################

function Get-AuditEvents {
    Log-Info "Getting audit events for User $UPN"
    
    return Get-MsGraphCollection "`deviceManagement/auditEvents?`$filter=actor/userPrincipalName eq '$UPN'"
}

####################################################

function Get-ManagedAppRegistrations {
    Log-Info "Getting managed app registrations for User $UPN"
    
    return Get-MsGraphCollection "users/$UserId/managedAppRegistrations?`$expand=appliedPolicies,intendedPolicies,operations"
}

####################################################

function Get-AppleVppEbooks {
    Log-Info "Getting Apple VPP EBooks for User $UPN"

    return Get-MsGraphCollection "deviceAppManagement/managedEbooks?`$filter=microsoft.graph.iosVppEBook/appleId eq '$UPN'"
}

####################################################

function Get-AppleDepSettings {
    Log-Info "Getting Apple DEP Settings for User $UPN"

    return Get-MsGraphCollection "deviceManagement/depOnboardingSettings?`$filter=appleIdentifier eq '$UPN'"
}

####################################################

function Get-AppInstallStatuses {
    Log-Info "Getting App Install Statuses for User $UPN"
    
    $AppStatuses = @()
    $AppCount = 0
    $DevicesContainer = @()

    foreach ($Device in $ManagedDevices) {
        $DeviceContainer = @{}
        $DeviceId = [string]$Device.id
        $AppStatusesByDevice = Get-MsGraphObject "users('$UserId')/mobileAppIntentAndStates('$DeviceId')"
        $AppsContainer = @()
        foreach ($App in $AppStatusesByDevice.mobileAppList) {
            $AppContainer = @{}
            $AppMetaData = Get-MsGraphObject "deviceAppManagement/mobileApps/$($App.applicationId)?`$select=id,displayName,publisher,privacyInformationUrl,informationUrl,owner,developer"
            $AppContainer.applicationId = $App.applicationId
            $AppContainer.installState = $App.installState
            $AppContainer.mobileAppIntent = $App.mobileAppIntent
            $AppContainer.displayVersion = $App.displayVersion
            $AppContainer.displayName = $AppMetaData.displayName
            $AppContainer.publisher = $AppMetaData.publisher
            $AppContainer.privacyInformationUrl = $AppMetaData.privacyInformationUrl
            $AppContainer.informationUrl = $AppMetaData.informationUrl
            $AppContainer.owner = $AppMetaData.owner
            $AppContainer.developer = $AppMetaData.developer
            $AppsContainer += $AppContainer
            $AppCount++
        }
        $DeviceContainer | Add-Member -MemberType NoteProperty -Name "deviceId" -Value $DeviceId
        $DeviceContainer | Add-Member -MemberType NoteProperty -Name "deviceName" -Value $Device.deviceName
        $DeviceContainer | Add-Member -MemberType NoteProperty -Name "installedApps" -Value $AppsContainer
        $DevicesContainer += $DeviceContainer
        $AppStatuses = $DevicesContainer
    }

    Log-Info "Found $($AppCount) app install statuses across $($ManagedDevices.Count) managed devices"

    return $AppStatuses
}

####################################################

function Get-EbookInstallStatuses {
    Log-Info "Getting Ebook Install Statuses for User $UPN"

    $Ebooks = Get-MsGraphCollection "deviceAppManagement/managedEBooks?`$expand=installSummary"

    $EbooksStatuses = @()

    foreach ($Ebook in $Ebooks) {
        Log-Verbose "Getting Ebook Install Status for Ebook '$($Ebook.displayName) $($Ebook.Id)"

        $UserStatusesForEbook = Get-MsGraphCollection "deviceAppManagement/managedEBooks/$($Ebook.id)/userStateSummary"
        $DeviceStatusesForEbook = Get-MsGraphCollection "deviceAppManagement/managedEBooks/$($Ebook.id)/deviceStates" 
        $DeviceStatusesForUser = @()
        $DeviceStatusesForUser += $DeviceStatusesForEbook | Where-Object { 
            $_.userName -ieq $UserDisplayName
        }

        $UserStatusesForUser = @()
        $UserStatusesForUser += $UserStatusesForEbook | Where-Object { 
            $_.userName -ieq $UserDisplayName
        }
        
        if ($UserStatusesForUser.Count -gt 0 -or $DeviceStatusesForUser.Count -gt 0) {
            Add-Member NoteProperty -InputObject $Ebook -Name "deviceStates" -Value @()
            foreach ($UserStatus in $DeviceStatusesForUser) {
                $Ebook.deviceStates += $UserStatus
            }
            Add-Member NoteProperty -InputObject $Ebook -Name "userStateSummary" -Value @()
            foreach ($UserStatus in $UserStatusesForUser) {
                $Ebook.userStateSummary += $UserStatus
            }
            $EbooksStatuses += $Ebook
        }
    }

    return $EbooksStatuses
}

####################################################

function Get-WindowsManagementAppHealthStates($ManagedDevices) {
    Log-Info "Getting WindowsManagementApp Status for User $UPN"
    $StatesForDevice = @()
    foreach ($ManagedDevice in $ManagedDevices) {
        # Escape any ' in the device name
        $EscapedDeviceName = $ManagedDevice.deviceName.Replace("'", "''")
        $StatesForDevice += Get-MsGraphCollection "deviceAppManagement/windowsManagementApp/healthStates?`$filter=deviceName eq '$($EscapedDeviceName)'"
    }

    return $StatesForDevice
}

####################################################

function Get-WindowsProtectionStates($ManagedDevices) {
    Log-Info "Getting Windows Protection States for User $UPN"
    $StatesForDevice = @()
    foreach ($ManagedDevice in $ManagedDevices) {
        $StatesForDevice += Get-MsGraphObject "deviceManagement/managedDevices/$($ManagedDevice.id)?`$expand=windowsProtectionState"
    }
}

####################################################

function Get-RemoteActionAudits {
    Log-Info "Getting Remote Action Audits for User $UPN"

    $RemoteActionAudits = Get-MsGraphCollection "deviceManagement/remoteActionAudits?`$filter=initiatedByUserPrincipalName eq '$UPN'"
    return $RemoteActionAudits | Where-Object { $_.initiatedByUserPrincipalName -ieq $UPN -or $_.userName -ieq $UPN }
}

####################################################

function Get-DeviceManagementTroubleshootingEvents {
    Log-Info "Getting Device Management Troubleshooting Events for user $UPN"
    return Get-MsGraphCollection "users/$($User.id)/deviceManagementTroubleshootingEvents"
}

####################################################

function Get-IosUpdateStatuses {
    Log-Info "Getting iOS Update Statuses for user $UPN"
    $IosUpdateStatuses = @(Get-MsGraphCollection "deviceManagement/iosUpdateStatuses" | Where-Object { $_.userPrincipalName -ieq $UPN })
    return $IosUpdateStatuses
}

####################################################

function Get-ManagedDeviceMobileAppConfigurationStatuses ($Devices) {
    Log-Info "Getting Mobile App Configurations Statuses for user $UPN"
    $MobileAppConfigurationsStatuses = @()
    $MobileAppConfigurations = Get-MsGraphCollection "deviceAppManagement/mobileAppConfigurations"
    
    $DeviceIds = $Devices | Select-Object -ExpandProperty id

    foreach ($MobileAppConfiguration in $MobileAppConfigurations) {
        $DeviceStatuses = Get-MsGraphCollection "deviceAppManagement/mobileAppConfigurations/$($MobileAppConfiguration.id)/deviceStatuses"
        $UserStatuses = Get-MsGraphCollection "deviceAppManagement/mobileAppConfigurations/$($MobileAppConfiguration.id)/userStatuses"


        $DeviceStatusesForUser = @()
        
        foreach ($DeviceId in $DeviceIds) {
            $DeviceStatusesForUser += $DeviceStatuses | Where-Object { 
                $_.id.Contains($DeviceId)
            }
        }

        $UserStatusesForUser = @()
        $UserStatusesForUser += $UserStatuses | Where-Object { 
            $_.userPrincipalName -ieq $UPN
        }

        if ($DeviceStatusesForUser.Count -gt 0 -or $UserStatusesForUser.Count -gt 0) {
            $MobileAppConfiguration | Add-Member -Name "deviceStatuses" -Value $DeviceStatusesForUser -MemberType NoteProperty
            $MobileAppConfiguration | Add-Member -Name "userStatuses" -Value $UserStatusesForUser -MemberType NoteProperty
            $MobileAppConfigurationsStatuses += $MobileAppConfiguration
        }
    }

    return $MobileAppConfigurationsStatuses
}

####################################################

function Get-DeviceManagementScriptRunStates ($ManagedDevices) {
    Log-Info "Getting Device Management Script Run States for user $UPN"
    $DeviceManagementScripts = Get-MsGraphCollection "deviceManagement/deviceManagementScripts"
    $DeviceManagementScriptRunStates = @()

    foreach ($DeviceManagementScript in $DeviceManagementScripts) {
        $UserRunStates = Get-MsGraphCollection "deviceManagement/deviceManagementScripts/$($DeviceManagementScript.id)/userRunStates"

        $UserRunStatesForUser = @()
        $UserRunStatesForUser += $UserRunStates | Where-Object { 
            $_.userPrincipalName -ieq $UPN
        }

        if ($UserRunStatesForUser.Count -gt 0) {
            $DeviceManagementScript | Add-Member -Name "userRunStates" -Value $UserRunStatesForUser -MemberType NoteProperty
            $DeviceManagementScriptRunStates += $DeviceManagementScript
        }
    }

    return $DeviceManagementScriptRunStates
}

####################################################

function Export-RemainingData {
    Log-Info "Getting other data for user $Upn"

    $OtherData = Get-MsGraphCollection "users/$Upn/exportDeviceAndAppManagementData()/content"
    if ($OtherData.Count -gt 0) {
        foreach ($DataItem in $OtherData) {
            if ($DataItem.data -ne $null) {
                $Entities = @($DataItem.data)
                if ($Entities.Count -gt 0) {
                    Log-Info "Found $($Entities.Count) $($DataItem.displayName)"
                    $CollectionName = $DataItem.displayName
                    if ($CollectionName -ieq "Users") {
                        $CollectionName = "Intune Users"
                    }
                    $EntityName = $CollectionName.TrimEnd('s')

                    Export-Collection -CollectionType $CollectionName -ObjectType $EntityName -Collection $Entities 
                }
                else {
                    Log-Info "No $($DataItem.displayName) data found"
                }
            }
        }
    }
}

####################################################

function Get-AppProtectionUserStatuses {
    Log-Info "Getting Managed App Protection Status Report for user $UPN"

    $Status = Get-MsGraphObject "deviceAppManagement/managedAppStatuses('userstatus')?userId=$UserId"

    return $Status
}

####################################################

function Get-ManagedAppUsageSummary {
    Log-Info "Getting Managed App Usage Summary for user $UPN"

    $UsageSummary = Get-MsGraphObject "deviceAppManagement/managedAppStatuses('appregistrationsummary')?fetch=6000&policyMode=0&columns=UserId,DisplayName,UserEmail,ApplicationName,ApplicationInstanceId,ApplicationVersion,DeviceName,DeviceType,DeviceManufacturer,DeviceModel,AndroidPatchVersion,AzureADDeviceId,MDMDeviceID,Platform,PlatformVersion,ManagementLevel,PolicyName,LastCheckInDate"
    $Report = $UsageSummary.content.body
    $FilteredRows = @()
    if ($Report.Count -gt 0) {
        foreach ($Row in $Report) {
            if ($Row.values[0] -ieq $UserId) {
                $FilteredRows += $Row
            }
        }
    }
    $Report = $FilteredRows
    $UsageSummary.content.body = $Report

    return $UsageSummary
}

####################################################

function Get-ManagedAppConfigurationStatusReport {
    Log-Info "Getting Managed App Configuration Status for user $UPN"
    $StatusReport = Get-MsGraphObject "deviceAppManagement/managedAppStatuses('userconfigstatus')?userId=$UserId"

    return $StatusReport
}

####################################################

function Filter-ManagedAppReport {
    param($Report)
    #Filter the report summary to only the target user
    if ($Report -ne $null -and $Report.content -ne $null) {
        $HeaderCount = $Report.content.header.Count
        $DataRows = $Report.content.body.values
        $FilteredDataRows = @()

        if ($DataRows.Count -eq $HeaderCount) {
            # Special case for only one row of data
            if ($DataRows[0] -ieq $UserId) {
                $FilteredDataRows += @($DataRows)
            }
        }
        elseif ($DataRows -ne $null -and $DataRows.Count -gt 0) {
            foreach ($DataRow in $DataRows) {
                if ($DataRow[0] -ieq $UserId) {
                    $FilteredDataRows += $DataRow
                }
            }
        }

        $DataRows = $FilteredDataRows
    }

    return $Report
}

####################################################

function Get-TermsAndConditionsAcceptanceStatuses {
    Log-Info "Exporting Terms and Conditions Acceptance Statuses for user $UPN"

    $TermsAndConditions = Get-MsGraphCollection "deviceManagement/termsAndConditions"
    $TermsAndConditionsAcceptanceStatuses = @()

    foreach ($TermsAndCondition in $TermsAndConditions) {
        $AcceptanceStatuses = Get-MsGraphCollection "deviceManagement/termsAndConditions/$($TermsAndCondition.id)/acceptanceStatuses"

        $TermsAndConditionsAcceptanceStatuses += ($AcceptanceStatuses | Where-Object { $_.id.Contains($UserId) })
    }

    return $TermsAndConditionsAcceptanceStatuses
}

####################################################

function Export-IntuneReportUsingGraph($RequestBody, $ZipName) {
    Log-Info "Exporting Intune Report Using Graph for user '$UPN'"

    $IntuneReportDataPOSTResponse = Post-MsGraphObject "deviceManagement/reports/exportJobs" $RequestBody
    Log-Verbose $IntuneReportDataPOSTResponse

    $ReportId = $IntuneReportDataPOSTResponse.Id
    $ReportIdPath = "deviceManagement/reports/exportJobs('" + $ReportId + "')"

    $Attempts = 0
    $MaxAttempts = 20
    do {
        Start-Sleep -Seconds 15
        $IntuneReportDataGETResponse = Get-MsGraphObject $ReportIdPath
        Log-Verbose $IntuneReportDataGETResponse
        $Attempts += 1
    }
    while (($IntuneReportDataGETResponse.status -ne "completed") -or $Attempts -ge $MaxAttempts)

    if ($Attempts -ge $MaxAttempts) {
        Log-Error "Attempt count exceeded, report not generated"
        return
    }

    $IntuneReportOutFile = $OutputPath + "/" + $ZipName + ".zip"
    $DownloadZipFile = Invoke-MgGraphRequest -Method Get -Uri $IntuneReportDataGETResponse.url -ContentType "application/zip" -OutputFilePath $IntuneReportOutFile
    Log-Verbose "Zip file downloaded to $IntuneReportOutFile"
}

####################################################

function Export-ChromeOSDeviceReportData {
    Log-Info "Exporting ChromeOS Device Report Data for user '$UPN'"

    $FilterString = "(MostRecentUserEmail eq '" + $UPN + "')"

    $ChromeRequestBody = @{ 
        reportName       = "ChromeOSDevices"
        localizationType = "LocalizedValuesAsAdditionalColumn"
        filter           = $FilterString
        format           = "json"
    }

    Export-IntuneReportUsingGraph $ChromeRequestBody "ChromeOSDeviceReport"
}

#endregion

####################################################

#region Export Functions

function Export-ObjectJson($ObjectType, $Object) {
    $ExportPath = $(Join-Path $OutputPath "$ObjectType.json")
    Log-Info "Writing $ObjectType data to $ExportPath"
    $Object | ConvertTo-Json -Depth 20 | Out-File -Encoding utf8 -FilePath $ExportPath
}

####################################################

function Export-ObjectCSV($ObjectType, $Object) {
    Log-Info "Writing $ObjectType data to $(Join-Path $OutputPath "$ObjectType.csv")"
    $Object | Export-Csv -NoTypeInformation -Path (Join-Path $OutputPath "$ObjectType.csv") -Encoding utf8 
}

####################################################

function Export-ObjectXML($ObjectType, $Object) {
    Log-Info "Writing $ObjectType data to $(Join-Path $OutputPath "$ObjectType.xml")"
    $Object | ConvertTo-XML -Depth 20 -NoTypeInformation -As String | Out-File -Encoding utf8 -FilePath (Join-Path $OutputPath "$ObjectType.xml")
}

####################################################

function Export-Object ($ObjectType, $Object) {
    Log-Info "Exporting data for $ObjectType ID:$($Object.id)"

    if (-not $All) {
        Filter-Entity -EntityName $ObjectType -Entity $Object
    }

    if ($ExportFormat -eq "CSV") {
        Export-ObjectCsv $ObjectType $Object
    }
    if ($ExportFormat -eq "JSON") {
        Export-ObjectJson $ObjectType $Object
    }
    if ($ExportFormat -eq "XML") {
        Export-ObjectXML $ObjectType $Object
    }
}

####################################################

function Export-Collection ($CollectionType, $ObjectType, $Collection) {
    if ($Collection.Count -eq 0) {
        Log-Info "No $ObjectType data found to export"
        return
    }

    if (-not $All) {
        $Collection | ForEach-Object { Filter-Entity -EntityName $ObjectType -Entity $_ }
    }

    if ($ExportFormat -eq "JSON") {
        $ExportPath = (Join-Path $OutputPath "$CollectionType.json")
        $Collection | ConvertTo-Json -Depth 20 | Out-File -Encoding utf8 -FilePath $ExportPath
        Log-Info "Exported $($Collection.Count) $CollectionType to $ExportPath"
    }
    if ($ExportFormat -eq "XML") {
        $ExportPath = (Join-Path $OutputPath "$CollectionType.xml")
        $Collection | ConvertTo-XML -Depth 20 -NoTypeInformation -As String | Out-File -Encoding utf8 -FilePath $ExportPath
        Log-Info "Exported $($Collection.Count) $CollectionType to $ExportPath"
    }
    if ($ExportFormat -eq "CSV") {
        $ExportPath = (Join-Path $OutputPath "$CollectionType.csv")
        $Collection | Export-Csv -NoTypeInformation -Path $ExportPath -Encoding utf8 
        Log-Info "Exported $($Collection.Count) $CollectionType to $ExportPath"
    }
}

#endregion

####################################################

function Filter-Entity {
    param(
        $EntityName,
        $Entity
    )

    Log-Verbose "Filtering entity $EntityName"

    if ($Entity -eq $null) {
        return
    }

    $AllEntityConfiguration = $ExportConfiguration.All
    $EntityConfiguration = $ExportConfiguration."$EntityName"

    $PropertiesToRemove = @()
    if ($AllEntityConfiguration.columnsToExclude.Count -gt 0) {
        $PropertiesToRemove += $AllEntityConfiguration.columnsToExclude
    }
    if ($EntityConfiguration.columnsToExclude.Count -gt 0) {
        $PropertiesToRemove += $EntityConfiguration.columnsToExclude
    }

    $PropertiesToRename = @()
    if ($AllEntityConfiguration.columnsToRename.Count -gt 0) {
        $PropertiesToRename += $AllEntityConfiguration.columnsToRename
    }
    if ($EntityConfiguration.columnsToRename.Count -gt 0) {
        $PropertiesToRename += $EntityConfiguration.columnsToRename
    }

    foreach ($PropertyToRemove in $PropertiesToRemove) {
        $Entity.PSObject.Properties.Remove($PropertyToRemove)
    }    

    foreach ($PropertyToRename in $PropertiesToRename) {
        $OldPropertyName = $PropertyToRename | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name

        #Check if the old property exists on the entity      
        $OldPropertyExists = (($Entity | Get-Member -MemberType NoteProperty -Name $OldPropertyName) -ne $null)

        if (-not $OldPropertyExists) {
            continue
        }

        $NewPropertyName = $PropertyToRename."$OldPropertyName"
        $PropertyValue = $Entity."$OldPropertyName"
        $Entity.PSObject.Properties.Remove("$OldPropertyName")
        Add-Member -MemberType NoteProperty -InputObject $Entity -Name $NewPropertyName -Value $PropertyValue
    }

    $NestedArrays = @($Entity | Get-Member -MemberType NoteProperty | Where-Object { $_.Definition.StartsWith("Object[]") })
    $NestedObjects = @($Entity | Get-Member -MemberType NoteProperty | Where-Object { $_.Definition.StartsWith("System.Management.Automation.PSCustomObject") })

    foreach ($NestedArray in $NestedArrays) {
        $Array = $Entity."$($NestedArray.Name)"
        if ($Array.Count -eq 0) {
            continue
        }
        foreach ($Value in $Array) {
            Filter-Entity -EntityName "$EntityName.$($NestedArray.Name)" -Entity $Value
        }
    }
    foreach ($NestedObject in $NestedObjects) {
        $Object = $Entity."$($NestedObject.Name)"
        Filter-Entity -EntityName "$EntityName.$($NestedObject.Name)" -Entity $Object
    }
}

Test-GraphSession $Username

####################################################

if (-not (Test-Path $OutputPath)) {
    Log-Verbose "Creating Folder $OutputPath"
    New-Item -ItemType Directory -Path $OutputPath | Out-Null
}

####################################################

if ([string]::IsNullOrWhiteSpace($ConfigurationFile)) {
    $ConfigurationFile = Join-Path $PSScriptRoot "ExportConfiguration.json"
}

Log-Verbose "Loading configuration from $ConfigurationFile"

if (Test-Path $ConfigurationFile) {
    $ExportConfiguration = (Get-Content $ConfigurationFile | ConvertFrom-Json)
}
else {
    Log-Warning "Configuration file $ConfigurationFile not found"
}

####################################################

$UPN = $Upn.ToLowerInvariant()

Log-Info "Exporting user data for user $Upn to $OutputPath"

if ($All) {
    Log-Info "All data will be exported"
}
elseif ($IncludeEntraID) {
    Log-Info "Including EntraID data in export"
} 

####################################################

# Get Data for Non EntraID UPN (if requested)

if ($IncludeNonEntraIDUpn -or $All) {
    Export-ChromeOSDeviceReportData
}

####################################################

$User = Get-User

if ($User -eq $null) {
    Log-Warning "Entra ID User with UPN $UPN was not found"
    return
}

$UserId = $User.id
Log-Info "Exporting data for user `"$($User.displayName)`" with UPN $($User.userPrincipalName) and ID $UserId"
$UserDisplayName = $User.displayName

####################################################

if (-not (Test-IntuneUser)) {
    Log-Warning "User with UPN $UPN is not a Microsoft Intune user"
    return
}

Log-Info "User is a valid Microsoft Intune user"

####################################################

if ($IncludeEntraID -or $All) {
    Export-Object "Entra ID User" $User

    $Groups = Get-GroupMemberships
    Export-Collection "Entra ID Groups" "Entra ID Group" $Groups

    $Groups = Get-RegisteredDevices
    Export-Collection "Entra ID Registered Devices" "Entra ID Registered Device" $Groups
}

####################################################

$ManagedDevices = Get-ManagedDevices
Export-Collection "ManagedDevices" "ManagedDevice" $ManagedDevices

$AuditEvents = Get-AuditEvents
Export-Collection "AuditEvents" "AuditEvent" $AuditEvents

$ManagedAppRegistrations = Get-ManagedAppRegistrations
Export-Collection "ManagedAppRegistrations" "ManagedAppRegistration" $ManagedAppRegistrations

$AppleDepSettings = Get-AppleDepSettings
Export-Collection "AppleDEPSettings" "AppleDEPSetting" $AppleDepSettings

$AppInstallStatuses = Get-AppInstallStatuses
Export-Collection "AppInstallStatuses" "AppInstallStatus" $AppInstallStatuses

$EbookInstallStatuses = Get-EbookInstallStatuses
Export-Collection "EbookInstallStatuses" "EbookInstallStatus" $EbookInstallStatuses

$WindowsManagementAppStatuses = Get-WindowsManagementAppHealthStates $ManagedDevices
Export-Collection "WindowsManagementAppHealthStates" "WindowsManagementApp" $WindowsManagementAppStatuses

$WindowsProtectionStates = Get-WindowsProtectionStates $ManagedDevices
Export-Collection "WindowsProtectionStates" "WindowsProtectionState" $WindowsProtectionStates

$RemoteActionAudits = Get-RemoteActionAudits
Export-Collection "RemoteActionAudits" "RemoteActionAudit" $RemoteActionAudits

$DeviceManagementTroubleshootingEvents = Get-DeviceManagementTroubleshootingEvents
Export-Collection "DeviceManagementTroubleshootingEvents" "DeviceManagementTroubleshootingEvents" $DeviceManagementTroubleshootingEvents

$IosUpdateStatues = Get-IosUpdateStatuses
Export-Collection "iOSUpdateStatus" "iOSUpdateStatuses" $IosUpdateStatues

$ManagedDeviceMobileAppConfigurationStatuses = Get-ManagedDeviceMobileAppConfigurationStatuses $ManagedDevices
Export-Collection "MobileAppConfigurationStatuses" "MobileAppConfigurationStatus" $ManagedDeviceMobileAppConfigurationStatuses

$DeviceManagementScriptRunStates = Get-DeviceManagementScriptRunStates 
Export-Collection "DeviceManagementScriptRunState" "DeviceManagementScriptRunStates" $DeviceManagementScriptRunStates

$AppProtectionUserStatus = Get-AppProtectionUserStatuses
Export-Object "ManagedAppProtectionStatusReport" $AppProtectionUserStatus

$ManagedAppUsageSummary = Get-ManagedAppUsageSummary
Export-Object "ManagedAppUsageSummary" $ManagedAppUsageSummary

$ManagedAppConfigurationStatusReport = Get-ManagedAppConfigurationStatusReport
Export-Object "ManagedAppConfigurationStatusReport" $ManagedAppConfigurationStatusReport

$TermsAndConditionsAcceptanceStatuses = Get-TermsAndConditionsAcceptanceStatuses
Export-Collection "TermsAndConditionsAcceptanceStatus" "TermsAndConditionsAcceptanceStatuses" $TermsAndConditionsAcceptanceStatuses

Export-RemainingData

Log-Info "Export complete, files can be found at $OutputPath"
Write-Host