<#
.SYNOPSIS
    Provides functions and a framework for uploading a win32 LOB app to Intune
.DESCRIPTION
    This is a sample script designed to be modified for your own use case.
.NOTES
    To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
    https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0

    The PowerShell SDK supports two types of authentication: delegated access, and app-only access.

    For details on using delegated access, see this guide here:
    https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0

    For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
    https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal
.EXAMPLE
    $DetectionRule = New-DetectionRule -Registry -RegistryKeyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{9224190b-b126-44ce-a2da-4bd9bcccf4bd}" -RegistryDetectionType string -check32BitRegOn64System False -RegistryValue "DisplayName" -RegistryDetectionValue "My LOB App v1.0"
    Create a registry detection rule. See the help info for New-DetectionRule for more information.
.EXAMPLE
    $ReturnCodes = @(@{"returnCode" = 0; "type" = "success" }, @{"returnCode" = 1707; "type" = "success" }, @{"returnCode" = 3010; "type" = "softReboot" }, @{"returnCode" = 1641; "type" = "hardReboot" }, @{"returnCode" = 1618; "type" = "retry" })
    Some default ReturnCodes that can be used for the returnCodes parameter
.EXAMPLE
    Publish-Win32LobApp -SourceFile ".\MyLobApp.intunewin" -Publisher "Contoso" -Description "A test application to deploy via Intune." -detectionRules $DetectionRule -returnCodes $ReturnCodes -installCmdLine "install.exe" -uninstallCmdLine "uninstall.exe" -BlockSizeMB 1
    Creates and publishes the given app
#>

#requires -module Microsoft.Graph.Devices.CorporateManagement
#requires -module Microsoft.Graph.Authentication

# An interactive logon using Connect-MgGraph's default app ID
Connect-MgGraph -Scopes DeviceManagementApps.ReadWrite.All -NoWelcome

#Path for temp copies of extracted files from the .intunewin file
$ExtractedPath = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName())

#Base URL for Graph API calls
$baseUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/"

$sleep = 30

function UploadAzureStorageChunk($sasUri, $id, $body) {
    <#
    .SYNOPSIS
        Uploads a chunk of data to the given Azure Storage URI
    #>
    $uri = "$sasUri&comp=block&blockid=$id"
    $request = "PUT $uri"

    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/octet-stream"
    }

    try {
        Invoke-WebRequest -Headers $headers $uri -Method Put -Body $body
    }
    catch {
        Write-Host -ForegroundColor Red $request
        Write-Host -ForegroundColor Red $_.Exception.Message
        throw
    }
}

function FinalizeAzureStorageUpload($sasUri, $ids) {
    <#
    .SYNOPSIS
        Finalizes the Azure Storage upload
    .DESCRIPTION
        Finalizes the Azure Storage upload by sending a blocklist to the Intune Service SAS URI location, joining the blocks together as a single file
    #>
    $uri = "$sasUri&comp=blocklist"
    $request = "PUT $uri"

    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>'
    foreach ($id in $ids) {
        $xml += "<Latest>$id</Latest>"
    }
    $xml += '</BlockList>'

    if ($logRequestUris) { Write-Host $request; }
    if ($logContent) { Write-Host -ForegroundColor Gray $xml; }

    $headers = @{
        "Content-Type" = "text/plain"
    }

    try {
        Invoke-WebRequest $uri -Method Put -Body $xml -Headers $headers
    }
    catch {
        Write-Host -ForegroundColor Red $request
        Write-Host -ForegroundColor Red $_.Exception.Message
        throw
    }
}

function UploadFileToAzureStorage($sasUri, $filepath, $blockSizeMB) {
    <#
    .SYNOPSIS
        Uploads a file to Azure Storage
    .DESCRIPTION
        Splits a given file into discrete chunks and uploads them to the Intune Service SAS URI location
    #>

    $FQFilePath = (Get-Item $filepath).FullName

    # Chunk size in MiB
    $chunkSizeInBytes = 1024 * 1024 * $blockSizeMB

    # Read the whole file and find the total chunks.
    $fileStream = [System.IO.File]::OpenRead($FQFilePath)
    $chunks = [Math]::Ceiling($fileStream.Length / $chunkSizeInBytes)

    # Upload each chunk.
    $ids = @()
    $cc = 1
    $chunk = 0
    while ($fileStream.Position -lt $fileStream.Length) {
        $id = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($chunk.ToString("0000")))
        $ids += $id

        $size = [Math]::Min($chunkSizeInBytes, $fileStream.Length - $fileStream.Position)
        $body = New-Object byte[] $size
        $fileStream.Read($body, 0, $size)
        $totalBytes += $size

        Write-Progress -Activity "Uploading File to Azure Storage" -Status "Uploading chunk $cc of $chunks" `
            -PercentComplete ($cc / $chunks * 100)
        $cc++

        UploadAzureStorageChunk $sasUri $id $body | Out-Null
        $chunk++
    }

    Write-Progress -Completed -Activity "Uploading File to Azure Storage"

    # Finalize the upload.
    FinalizeAzureStorageUpload $sasUri $ids | Out-Null
}

function WaitForFileProcessing($fileUri, $stage) {
    <#
    .SYNOPSIS
        Wait for file processing to complete
    .DESCRIPTION
        Wait for file processing to complete by polling the file upload state
    #>
    $attempts = 60
    $waitTimeInSeconds = 1
    $successState = "$($stage)Success"
    $pendingState = "$($stage)Pending"

    $file = $null
    while ($attempts -gt 0) {
        $file = Invoke-MgGraphRequest -Method GET -Uri $fileUri
        if ($file.uploadState -eq $successState) {
            break
        }
        elseif ($file.uploadState -ne $pendingState) {
            throw "File upload state is not success: $($file.uploadState)"
        }

        Start-Sleep $waitTimeInSeconds
        $attempts--
    }

    if ($null -eq $file) {
        throw "File request did not complete in the allotted time."
    }

    return $file
}

function GetWin32AppBody {
    <#
    .SYNOPSIS
        Gets the appropriate body for the Win32 app creation request
    .DESCRIPTION
        Creates a hashtable that corresponds to the #microsoft.graph.win32LobApp object in the Intune Graph API
    #>
    param
    (
        [parameter(Mandatory = $true, ParameterSetName = "MSI", Position = 1)]
        [Switch]$MSI,
        [parameter(Mandatory = $true, ParameterSetName = "EXE", Position = 1)]
        [Switch]$EXE,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$publisher,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$description,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$filename,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SetupFileName,
        [ValidateSet('system', 'user')]
        $installExperience = 'system',
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        $installCommandLine,
        [parameter(Mandatory = $true, ParameterSetName = "EXE")]
        [ValidateNotNullOrEmpty()]
        $uninstallCommandLine,
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiPackageType,
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiProductCode,
        [parameter(Mandatory = $false, ParameterSetName = "MSI")]
        $MsiProductName,
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiProductVersion,
        [parameter(Mandatory = $false, ParameterSetName = "MSI")]
        $MsiPublisher,
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiRequiresReboot,
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        $MsiUpgradeCode
    )
    $body = @{
        "@odata.type" = "#microsoft.graph.win32LobApp"
        description = $description
        displayName = $displayName
        fileName = $filename
        developer = ""
        installExperience = @{"runAsAccount" = "$installExperience" }
        informationUrl = $null
        isFeatured = $false
        runAs32bit = $false
        setupFilePath = $SetupFileName
        notes = ""
        owner = ""
        privacyInformationUrl = $null
        publisher = $publisher
        minimumSupportedOperatingSystem = @{"v10_1607" = $true }
    }

    if ($MSI) {
        $body.installCommandLine = "msiexec /i `"$SetupFileName`""
        $body.applicableArchitectures = "x64,x86"
        $body.msiInformation = @{
            packageType    = $MsiPackageType
            productCode    = $MsiProductCode
            productName    = $MsiProductName
            productVersion = $MsiProductVersion
            publisher      = $MsiPublisher
            requiresReboot = $MsiRequiresReboot
            upgradeCode    = $MsiUpgradeCode
        }
        $body.uninstallCommandLine = "msiexec /x `"$MsiProductCode`""
    }

    elseif ($EXE) {
        $body.installCommandLine = "$installCommandLine"
        $body.msiInformation = $null
        $body.uninstallCommandLine = "$uninstallCommandLine"
    }

    return $body
}
Function Get-IntuneWinFile() {
    <#
    .SYNOPSIS
        Extracts a file from an IntuneWin file
    .DESCRIPTION
        Extracts a given file from a given IntuneWin file to the directory specified in $Folder
    .PARAMETER SourceFile
        The path to the .intunewin source file
    .PARAMETER fileName
        The name of the file to extract from the .intunewin file
    .PARAMETER Folder
        The folder to extract the file to
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [String]$SourceFile,
        [Parameter(Mandatory = $true)]
        [String]$fileName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrWhiteSpace()]
        [String]$Folder
    )
    if (!(Test-Path "$Folder")) {
        New-Item -ItemType Directory $Folder | Out-Null
    }

    $FQSourceFile = (Get-Item $SourceFile).FullName

    $OutputFile = "$Folder\$fileName"

    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($FQSourceFile)

    $zip.Entries | Where-Object { $_.Name -like "$filename" } | ForEach-Object {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, $OutputFile, $true)
    }

    $zip.Dispose()

    return $OutputFile
}

function Publish-Win32LobApp() {
    <#
    .SYNOPSIS
        Publishes a Win32 LOB application to Intune
    .DESCRIPTION
        This function publishes a Win32 LOB application to Intune including uploading the app content.

        The intunewin file can be generated using the IntuneWinAppUtil.exe tool provided by Microsoft.

        Once your app is published you will likely want to create assignments using New-MgDeviceAppManagementMobileAppAssignment
    .PARAMETER SourceFile
        The path to the .intunewin source file of the application
    .PARAMETER displayName
        The display name of the application
    .PARAMETER publisher
        The publisher of the application
    .PARAMETER description
        The description of the application
    .PARAMETER detectionRules
        The detection rules for the application, expected to be a hashtable of the appropriate type, such as #microsoft.graph.win32LobAppPowerShellScriptDetection. See New-DetectionRule
    .PARAMETER returnCodes
        The return codes for the application in an array of hashtables, each containing a returnCode and type. See the example
    .PARAMETER installCmdLine
        The installation command line for the application. This parameter is optional but cannot be null or empty if provided.
    .PARAMETER uninstallCmdLine
        The command line to be run to install the application
    .PARAMETER installExperience
        Whether the installation runs as system or as a user.
    .PARAMETER BlockSizeMB
        The block size in MB for uploading the application. Default = 1
    .EXAMPLE
        Publish-Win32LobApp -SourceFile ".\MyLobApp.intunewin" -Publisher "Contoso" -Description "A test application to deploy via Intune." -detectionRules $DetectionRule -returnCodes $ReturnCodes -installCmdLine "install.exe" -uninstallCmdLine "uninstall.exe" -BlockSizeMB 1
        Creates and publishes the given app
    .EXAMPLE
        $ReturnCodes = @(@{"returnCode" = 0; "type" = "success" }, @{"returnCode" = 1707; "type" = "success" }, @{"returnCode" = 3010; "type" = "softReboot" }, @{"returnCode" = 1641; "type" = "hardReboot" }, @{"returnCode" = 1618; "type" = "retry" })
        Some default ReturnCodes that can be used for the returnCodes parameter
    #>
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [string]$SourceFile,
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,
        [parameter(Mandatory = $true, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$publisher,
        [parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$description,
        [parameter(Mandatory = $true, Position = 4)]
        [ValidateNotNullOrEmpty()]
        $detectionRules,
        [parameter(Mandatory = $true, Position = 5)]
        [ValidateNotNullOrEmpty()]
        $returnCodes,
        [parameter(Mandatory = $false, Position = 6)]
        [ValidateNotNullOrEmpty()]
        [string]$installCmdLine,
        [parameter(Mandatory = $false, Position = 7)]
        [ValidateNotNullOrEmpty()]
        [string]$uninstallCmdLine,
        [parameter(Mandatory = $false, Position = 8)]
        [ValidateSet('system', 'user')]
        $installExperience = "system",
        [parameter(Mandatory = $false, Position = 9)]
        [uint32]$BlockSizeMB = 1
    )
    try	{
        $LOBType = "microsoft.graph.win32LobApp"

        Write-Host "Creating JSON data to pass to the service..." -ForegroundColor Yellow

        [xml]$DetectionXML = Get-Content (Get-IntuneWinFile $SourceFile -FileName "detection.xml" -Folder $ExtractedPath)

        # If displayName input don't use Name from detection.xml file
        if ($displayName) { $DisplayName = $displayName }
        else { $DisplayName = $DetectionXML.ApplicationInfo.Name }
        
        $FileName = $DetectionXML.ApplicationInfo.FileName

        $SetupFileName = $DetectionXML.ApplicationInfo.SetupFile

        $Ext = [System.IO.Path]::GetExtension($SetupFileName)

        if ((($Ext).contains("msi") -or ($Ext).contains("Msi")) -and (!$installCmdLine -or !$uninstallCmdLine)) {
            # MSI
            $MsiExecutionContext = $DetectionXML.ApplicationInfo.MsiInfo.MsiExecutionContext
            $MsiPackageType = "DualPurpose"
            if ($MsiExecutionContext -eq "System") { $MsiPackageType = "PerMachine" }
            elseif ($MsiExecutionContext -eq "User") { $MsiPackageType = "PerUser" }

            $MsiProductCode = $DetectionXML.ApplicationInfo.MsiInfo.MsiProductCode
            $MsiProductVersion = $DetectionXML.ApplicationInfo.MsiInfo.MsiProductVersion
            $MsiPublisher = $DetectionXML.ApplicationInfo.MsiInfo.MsiPublisher
            $MsiRequiresReboot = $DetectionXML.ApplicationInfo.MsiInfo.MsiRequiresReboot
            $MsiUpgradeCode = $DetectionXML.ApplicationInfo.MsiInfo.MsiUpgradeCode
            
            if ($MsiRequiresReboot -eq "false") { $MsiRequiresReboot = $false }
            elseif ($MsiRequiresReboot -eq "true") { $MsiRequiresReboot = $true }

            $Body = GetWin32AppBody `
                -MSI `
                -displayName "$DisplayName" `
                -publisher "$publisher" `
                -description $description `
                -filename $FileName `
                -SetupFileName "$SetupFileName" `
                -installExperience $installExperience `
                -MsiPackageType $MsiPackageType `
                -MsiProductCode $MsiProductCode `
                -MsiProductName $displayName `
                -MsiProductVersion $MsiProductVersion `
                -MsiPublisher $MsiPublisher `
                -MsiRequiresReboot $MsiRequiresReboot `
                -MsiUpgradeCode $MsiUpgradeCode
        }
        else {
            $Body = GetWin32AppBody -EXE -displayName "$DisplayName" -publisher "$publisher" `
                -description $description -filename $FileName -SetupFileName "$SetupFileName" `
                -installExperience $installExperience -installCommandLine $installCmdLine `
                -uninstallCommandLine $uninstallcmdline
        }

        if ($DetectionRules.'@odata.type' -contains "#microsoft.graph.win32LobAppPowerShellScriptDetection" -and @($DetectionRules).'@odata.type'.Count -gt 1) {
            Write-Warning "A Detection Rule can either be 'Manually configure detection rules' or 'Use a custom detection script'"
            Write-Warning "It can't include both..."
            break
        }
        else {
            $Body | Add-Member -MemberType NoteProperty -Name 'rules' -Value @($detectionRules)
        }

        $Body | Add-Member -MemberType NoteProperty -Name 'returnCodes' -Value @($returnCodes)

        Write-Host "Creating application in Intune..." -ForegroundColor Yellow
        try {
            $mobileApp = Invoke-MgGraphRequest -Method POST -Uri "$baseUrl/mobileApps" -Body ($Body | ConvertTo-Json) -ContentType "application/json; charset=iso-8859-1" -ErrorAction Stop
        }
        catch {
            Write-Error "Failed to create the application in Intune. Aborting."
            throw $_
        }

        # Get the content version for the new app (this will always be 1 until the new app is committed).
        Write-Host "Creating Content Version in the service for the application..." -ForegroundColor Yellow
        $appId = $mobileApp.id
        $contentVersionUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions"
        $contentVersion = Invoke-MgGraphRequest -Method POST -Uri $contentVersionUri "{}" -ContentType "application/json; charset=iso-8859-1"

        # Encrypt file and Get File Information
        Write-Host "Getting Encryption Information for '$SourceFile'..." -ForegroundColor Yellow

        $EncryptionInfo = $DetectionXML.ApplicationInfo.EncryptionInfo

        $fileEncryptionInfo = @{
            fileEncryptionInfo = [ordered]@{
                encryptionKey        = $EncryptionInfo.EncryptionKey
                macKey               = $EncryptionInfo.macKey
                initializationVector = $EncryptionInfo.initializationVector
                mac                  = $EncryptionInfo.mac
                profileIdentifier    = "ProfileVersion1"
                fileDigest           = $EncryptionInfo.fileDigest
                fileDigestAlgorithm  = $EncryptionInfo.fileDigestAlgorithm
            }
        } | ConvertTo-Json

        # Extracting encrypted file
        $IntuneWinFile = Get-IntuneWinFile $SourceFile -fileName $filename -Folder $ExtractedPath

        [int64]$Size = $DetectionXML.ApplicationInfo.UnencryptedContentSize
        $EncrySize = (Get-Item "$IntuneWinFile").Length

        # Create a new file for the app.
        Write-Host "Creating a new file entry in Azure for the upload..." -ForegroundColor Yellow
        $contentVersionId = $contentVersion.id
        $fileBody = @{
            "@odata.type" = "#microsoft.graph.mobileAppContentFile"
            name          = $FileName
            size          = $Size
            sizeEncrypted = $EncrySize
            manifest      = $null
            isDependency  = $false
        }
        $filesUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files"
        $file = Invoke-MgGraphRequest -Method POST -Uri $filesUri ($fileBody | ConvertTo-Json)

        # Wait for the service to process the new file request.
        Write-Host "Waiting for the file entry URI to be created..." -ForegroundColor Yellow
        $fileId = $file.id
        $fileUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files/$fileId"
        $file = WaitForFileProcessing $fileUri "AzureStorageUriRequest"

        # Upload the content to Azure Storage.
        Write-Host "Uploading file to Azure Storage..." -f Yellow
        UploadFileToAzureStorage $file.azureStorageUri $IntuneWinFile $BlockSizeMB

        # Commit the file.
        Write-Host "Committing the file into Azure Storage..." -ForegroundColor Yellow
        $commitFileUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files/$fileId/commit"
        Invoke-MgGraphRequest -Method POST $commitFileUri -Body $fileEncryptionInfo

        # Wait for the service to process the commit file request.
        Write-Host "Waiting for the service to process the commit file request..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "CommitFile"

        # Commit the app.
        Write-Host "Committing the app body..." -ForegroundColor Yellow
        $commitAppBody = @{
            "@odata.type" = "#$LOBType"
            committedContentVersion = $contentVersionId
        }
        Update-MgDeviceAppMgtMobileApp -MobileAppId $appId -BodyParameter ($commitAppBody | ConvertTo-Json)

        Write-Host "Sleeping for $sleep seconds to allow patch completion..." -f Magenta
        Start-Sleep $sleep

        # Display the app information from the Intune service
        $FinalAppStatus = (Get-MgDeviceAppManagementMobileApp -MobileAppId $appId)
        if ($FinalAppStatus.PublishingState -eq "published") {
            Write-Host "Application '$displayName' has been successfully uploaded to Intune." -ForegroundColor Green
        }
        else {
            Write-Host "Application '$displayName' has failed to upload to Intune." -ForegroundColor Red
        }
        $FinalAppStatus | Format-List
    }
    catch {
        Write-Error "Aborting with exception: $($_.Exception.ToString())"
        throw $_
    }
    finally {
        # Cleaning up temporary files and directories
        Remove-Item -Path $ExtractedPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Function New-DetectionRule() {
    <#
    .SYNOPSIS
        Creates a detection rule for a Win32 LOB application
    .DESCRIPTION
        This function creates a detection rule for a Win32 LOB application. The function will return a hashtable that can be used in the detectionRules parameter of Publish-Win32LobApp
    .EXAMPLE
        New-DetectionRule -Registry -RegistryKeyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{9224190b-b126-44ce-a2da-4bd9bcccf4bd}" -RegistryDetectionType string -check32BitRegOn64System False -RegistryValue "DisplayName" -RegistryDetectionValue "My LOB App v1.0"
        Will create a registry detection rule that will look for the DisplayName value on the given GUID in the Uninstall key.
    #>
    
    
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell", Position = 1)]
        [Switch]$PowerShell,
        [parameter(Mandatory = $true, ParameterSetName = "MSI", Position = 1)]
        [Switch]$MSI,
        [parameter(Mandatory = $true, ParameterSetName = "File", Position = 1)]
        [Switch]$File,
        [parameter(Mandatory = $true, ParameterSetName = "Registry", Position = 1)]
        [Switch]$Registry,
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell")]
        [ValidateScript({ Test-Path $_ -PathType Leaf })]
        [String]$FilePath,
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell")]
        [ValidateNotNullOrEmpty()]
        $enforceSignatureCheck,
        [parameter(Mandatory = $true, ParameterSetName = "PowerShell")]
        [ValidateNotNullOrEmpty()]
        $runAs32Bit,
        [parameter(Mandatory = $true, ParameterSetName = "MSI")]
        [ValidateNotNullOrEmpty()]
        [String]$MSIproductCode,
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateNotNullOrEmpty()]
        [String]$Path,
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateNotNullOrEmpty()]
        [string]$FileOrFolderName,
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateSet("notConfigured", "exists", "modifiedDate", "createdDate", "version", "sizeInMB")]
        [string]$FileDetectionType,
        [parameter(Mandatory = $false, ParameterSetName = "File")]
        $FileDetectionValue = $null,
        [parameter(Mandatory = $true, ParameterSetName = "File")]
        [ValidateSet("True", "False")]
        [bool]$check32BitOn64System = $False,
        [parameter(Mandatory = $true, ParameterSetName = "Registry")]
        [ValidateNotNullOrEmpty()]
        [String]$RegistryKeyPath,
        [parameter(Mandatory = $true, ParameterSetName = "Registry")]
        [ValidateSet("notConfigured", "exists", "doesNotExist", "string", "integer", "version")]
        [string]$RegistryDetectionType,
        [parameter(Mandatory = $false, ParameterSetName = "Registry")]
        [ValidateNotNullOrEmpty()]
        [String]$RegistryValue,
        [parameter(Mandatory = $false, ParameterSetName = "Registry")]
        [ValidateNotNullOrEmpty()]
        [String]$RegistryDetectionValue,
        [parameter(Mandatory = $true, ParameterSetName = "Registry")]
        [ValidateSet("True", "False")]
        [string]$check32BitRegOn64System = "False"
    )
    if ($PowerShell) {
        $ScriptContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($ScriptFile))
        $DR = @{ "@odata.type" = "microsoft.graph.win32LobAppPowerShellScriptRule" }
        $DR.enforceSignatureCheck = $false
        $DR.runAs32Bit = $false
        $DR.scriptContent = "$ScriptContent"
    }
    elseif ($MSI) {
        $DR = @{ "@odata.type" = "microsoft.graph.win32LobAppProductCodeRule" }
        $DR.productVersionOperator = "notConfigured"
        $DR.productCode = "$MsiProductCode"
        $DR.productVersion = $null
    }
    elseif ($File) {
        $DR = @{ "@odata.type" = "microsoft.graph.win32LobAppFileSystemRule" }
        $DR.check32BitOn64System = "$check32BitOn64System"
        $DR.operationType = "$FileDetectionType"
        $DR.comparisonValue = $FileDetectionValue
        $DR.fileOrFolderName = "$FileOrFolderName"
        $DR.operator = "notConfigured"
        $DR.path = "$Path"
    }
    elseif ($Registry) {
        $DR = @{ "@odata.type" = "microsoft.graph.win32LobAppRegistryRule" }
        $DR.check32BitOn64System = $check32BitRegOn64System
        $DR.operationType = "$RegistryDetectionType"
        $DR.comparisonValue = "$RegistryDetectionValue"
        $DR.keyPath = "$RegistryKeyPath"
        $DR.operator = "equal"
        $DR.valueName = "$RegistryValue"
    }
    $DR.ruleType = "detection"
    return $DR
}
