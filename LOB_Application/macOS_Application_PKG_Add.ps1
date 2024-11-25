#requires -module Microsoft.Graph.Beta.Devices.CorporateManagement
#requires -module Microsoft.Graph.Authentication

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0
The PowerShell SDK supports two types of authentication: delegated access, and app-only access.
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarmacOS, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal
#>

<#
.SYNOPSIS
Uploads an unmanaged macOS PKG application to Intune.

.DESCRIPTION
This script uploads an unmanaged macOS PKG application to Intune. The script creates a new mobileApp object in the Intune service, uploads the PKG file to Azure Storage, and commits the file to the mobileApp object. Additionally, the script supports preInstall and postInstall scripts when creating the application.

.PARAMETER SourceFile
The path to the PKG file to upload.

.PARAMETER displayName
The display name of the application.

.PARAMETER Publisher
The publisher of the application.

.PARAMETER Description
The description of the application.

.PARAMETER primaryBundleId
The primary bundle ID of the application that will be used for reporting.

.PARAMETER primaryBundleVersion
The primary bundle version of the application.

.PARAMETER includedApps
An array of includedApps objects that represent the included applications in the PKG file. Each includedApps object should have the following properties:
- bundleId: The bundle ID of the included application.
- bundleVersion: The bundle version of the included application.
- "@odata.type": The type of the included application. This should always be "microsoft.graph.macOSIncludedApp".

.PARAMETER minimumSupportedOperatingSystem
The minimum supported operating system for the application. The default value is v10_13.

.PARAMETER ignoreVersionDetection
A boolean value that indicates whether to ignore version detection when uploading the application.

.PARAMETER preInstallScriptPath
The path to the preInstall script to run before installing the application.

.PARAMETER postInstallScriptPath
The path to the postInstall script to run after installing the application.

.EXAMPLE
# This example uploads the Remote Help application to Intune.

## First, create an array of includedApps objects that represent the included applications in the PKG file.
$includedApps = @(
    @{
        "@odata.type" = "microsoft.graph.macOSIncludedApp"
        bundleId      = "com.microsoft.remotehelp"
        bundleVersion = "1.0"
    }
)

## Then, run the Invoke-macOSLobAppUpload function with the required parameters.
Invoke-macOSLobAppUpload -SourceFile "E:\Microsoft_Remote_Help_1.0.2409052_installer.pkg" -displayName "Remote Help" -Publisher "Microsoft" -Description "Remote Help for macOS" -primaryBundleId "com.microsoft.remotehelp" -primaryBundleVersion "1.0" -includedApps $includedApps -minimumSupportedOperatingSystem @{v10_13 = $true } -ignoreVersionDetection $true

.EXAMPLE
# This example uploads the Company Portal application to Intune.
## First, create an array of includedApps objects that represent the included applications in the PKG file.
$includedApps = @(
    @{
        "@odata.type" = "microsoft.graph.macOSIncludedApp"
        bundleId      = "com.microsoft.com.microsoft.CompanyPortalMac"
        bundleVersion = "4.74"
    }
)

## Then, run the Invoke-macOSLobAppUpload function with the required parameters. Note the preInstallScriptPath and postInstallScriptPath parameters are optional.
Invoke-macOSLobAppUpload -SourceFile "E:\CompanyPortal-Installer.pkg" -displayName "Company Portal" -Publisher "Microsoft" -Description "Company Portal for macOS" -primaryBundleId "com.microsoft.com.microsoft.CompanyPortalMac" -primaryBundleVersion "5.2409.1" -includedApps $includedApps -minimumSupportedOperatingSystem @{v10_13 = $true } -ignoreVersionDetection $true -preInstallScriptPath "E:\preInstall.sh" -postInstallScriptPath "E:\postInstall.sh"
#>
function Invoke-macOSLobAppUpload() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$SourceFile,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$displayName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Publisher,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [String]$Description,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$primaryBundleId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$primaryBundleVersion,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [hashtable[]]$includedApps,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]$minimumSupportedOperatingSystem,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [bool]$ignoreVersionDetection,
        [Parameter(Mandatory = $false)]
        [String]$preInstallScriptPath,
        [Parameter(Mandatory = $false)]
        [String]$postInstallScriptPath
    )
    try {
        # Check if the file exists and has a .Pkg extension
        if (!(Test-Path $SourceFile) -or (Get-Item $SourceFile).Extension -ne '.Pkg') {
            Write-Error "The provided path does not exist or is not an .Pkg file."
            throw
        }

        #Check if minmumSupportedOperatingSystem is provided. If not, default to v10_13
        if ($minimumSupportedOperatingSystem -eq $null) {
            $minimumSupportedOperatingSystem = @{ v10_13 = $true }
        }

        # Creating temp file name from Source File path
        $tempFile = [System.IO.Path]::GetDirectoryName("$SourceFile") + "\" + [System.IO.Path]::GetFileNameWithoutExtension("$SourceFile") + [guid]::NewGuid().ToString() + "_temp.bin"
        $fileName = (Get-Item $SourceFile).Name

        #Creating Intune app body JSON data to pass to the service
        Write-Host "Creating JSON data to pass to the service..." -ForegroundColor Yellow
        $body = New-macOSAppBody -displayName $displayName -Publisher $Publisher -Description $Description -fileName $fileName -primaryBundleId $primaryBundleId -primaryBundleVersion $primaryBundleVersion -includedApps $includedApps -minimumSupportedOperatingSystem $minimumSupportedOperatingSystem -ignoreVersionDetection $ignoreVersionDetection -preInstallScriptPath $preInstallScriptPath -postInstallScriptPath $postInstallScriptPath 

        # Create the Intune application object in the service
        Write-Host "Creating application in Intune..." -ForegroundColor Yellow
        $mobileApp = New-MgBetaDeviceAppManagementMobileApp -BodyParameter $body
        $mobileAppId = $mobileApp.id

        # Get the content version for the new app (this will always be 1 until the new app is committed).
        Write-Host "Creating Content Version in the service for the application..." -ForegroundColor Yellow
        $ContentVersion = New-MgBetaDeviceAppManagementMobileAppAsMacOSPkgAppContentVersion -MobileAppId $mobileAppId -BodyParameter @{}
        $ContentVersionId = $ContentVersion.id

        # Encrypt file and get file information
        Write-Host "Encrypting the copy of file '$SourceFile'..." -ForegroundColor Yellow
        
        $encryptionInfo = EncryptFile $SourceFile $tempFile
        $Size = (Get-Item "$SourceFile").Length
        $EncrySize = (Get-Item "$tempFile").Length

        $ContentVersionFileBody = @{
            name          = $fileName
            size          = $Size
            sizeEncrypted = $EncrySize
            manifest      = $null
            isDependency  = $false
            "@odata.type" = "#microsoft.graph.mobileAppContentFile"
        }

        # Create a new file entry in Azure for the upload
        Write-Host "Creating a new file entry in Azure for the upload..." -ForegroundColor Yellow
        $ContentVersionFile = New-MgBetaDeviceAppManagementMobileAppAsMacOSPkgAppContentVersionFile -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -BodyParameter $ContentVersionFileBody
        $ContentVersionFileId = $ContentVersionFile.id

        # Get the file URI for the upload
        $fileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$mobileAppId/microsoft.graph.macOSPkgApp/contentVersions/$contentVersionId/files/$contentVersionFileId"

        # Wait for the service to process the file upload request.
        Write-Host "Waiting for the service to process the file upload request..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "AzureStorageUriRequest"
        $sasUriRenewTime = $file.azureStorageUriExpirationDateTime.AddMinutes(-3)

        # Upload the content to Azure Storage.
        Write-Host "Uploading file to Azure Storage..." -f Yellow
        [UInt64]$BlockSizeMB = 4
        UploadFileToAzureStorage $file.azureStorageUri $sasUriRenewTime $tempFile $BlockSizeMB 

        Write-Host "Committing the file to the service..." -ForegroundColor Yellow
        Invoke-MgBetaCommitDeviceAppManagementMobileAppMicrosoftGraphMacOSPkgAppContentVersionFile -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -MobileAppContentFileId $ContentVersionFileId -BodyParameter ($encryptionInfo | ConvertTo-Json)

        # Wait for the service to process the commit file request.
        Write-Host "Waiting for the service to process the file commit request..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "CommitFile"

        # Commit the app.
        Write-Host "Committing the content version..." -ForegroundColor Yellow
        $params = @{
            "@odata.type"           = "#microsoft.graph.macOSPkgApp"
            committedContentVersion = "1"
        }
        
        Update-MgBetaDeviceAppManagementMobileApp -MobileAppId $mobileAppId -BodyParameter $params

        # Wait for the service to process the commit app request.
        Write-Host "Waiting for the service to process the app commit request..." -ForegroundColor Yellow

        $AppCheckAttempts = 25
        while ($AppCheckAttempts -gt 0) {
            $AppCheckAttempts--
            $AppStatus = Get-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId
            if ($AppStatus.PublishingState -eq "published") {
                Write-Host "Application created successfully." -ForegroundColor Green
                break
            }
            Start-Sleep -Seconds 3
        }

        if ($AppStatus.PublishingState -ne "published" -and $AppStatus.PublishingState -ne "processing") {
            Write-Host "Application '$displayName' has failed to upload to Intune." -ForegroundColor Red
            throw "Application '$displayName' has failed to upload to Intune."
        }
        else {
            Write-Host "Application '$displayName' has been successfully uploaded to Intune." -ForegroundColor Green
            $AppStatus | Format-List
        }
    }
    catch {
        Write-Host "Application '$displayName' has failed to upload to Intune." -ForegroundColor Red
        # In the event that the creation of the app record in Intune succeeded, but processing/file upload failed, you can remove the comment block around the code below to delete the app record.
        # This will allow you to re-run the script without having to manually delete the incomplete app record.
        # Note: This will only work if the app record was successfully created in Intune.

        <#
        if ($mobileAppId) {
            Write-Host "Removing the incomplete application record from Intune..." -ForegroundColor Yellow
            Remove-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId
        }
        #>
        Write-Error "Aborting with exception: $($_.Exception.ToString())"
        throw $_
    }
    finally {
        # Cleaning up temporary files and directories
        Remove-Item -Path "$tempFile" -Force -ErrorAction SilentlyContinue
    }
}

####################################################
# Function that uploads a source file chunk to the Intune Service SAS URI location.
function UploadAzureStorageChunk($sasUri, $id, $body) {
    $uri = "$sasUri&comp=block&blockid=$id"
    $request = "PUT $uri"

    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/octet-stream"
        "Connection"     = "Keep-Alive"
        "Content-Length" = $body.Length
        "Accept"         = "*/*"
    }

    try {
        Invoke-WebRequest -Headers $headers -Uri $uri -Method Put -Body $body -RetryIntervalSec 2 -MaximumRetryCount 300 
    }
    catch {
        Write-Host -ForegroundColor Red $request
        Write-Host -ForegroundColor Red $_.Exception.Message
        throw
    }
}

####################################################
# Function that takes all the chunk ids and joins them back together to recreate the file
function FinalizeAzureStorageUpload($sasUri, $ids) {
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

####################################################
# Function that splits the source file into chunks and calls the upload to the Intune Service SAS URI location, and finalizes the upload
function UploadFileToAzureStorage($sasUri, $sasUriRenewTime, $filepath, $blockSizeMB) {
    # Chunk size in MiB
    $chunkSizeInBytes = 1024 * 1024 * $blockSizeMB
    $fileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$mobileAppId/microsoft.graph.macOSPkgApp/contentVersions/$contentVersionId/files/$contentVersionFileId"

    # Read the whole file and find the total chunks.
    $fileStream = [System.IO.File]::OpenRead($filepath)
    $chunks = [Math]::Ceiling($fileStream.Length / $chunkSizeInBytes)

    # Upload each chunk.
    $ids = New-Object System.Collections.ArrayList
    $cc = 1
    $chunk = 0
    while ($fileStream.Position -lt $fileStream.Length) {
        $id = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($chunk.ToString("0000")))
        $ids.Add($id) > $null

        $size = [Math]::Min($chunkSizeInBytes, $fileStream.Length - $fileStream.Position)
        $body = New-Object byte[] $size
        $fileStream.Read($body, 0, $size) > $null

        "Uploading chunk $cc of $chunks"
        $cc++

        UploadAzureStorageChunk $sasUri $id $body | Out-Null
        $chunk++

        # Renew the SAS URI if it is about to expire.
        if ((Get-Date).ToUniversalTime() -ge $sasUriRenewTime) {
            Write-Host "Renewing the SAS URI for the file upload..." -ForegroundColor Yellow
            Invoke-MgBetaRenewDeviceAppManagementMobileAppMicrosoftGraphMacOSPkgAppContentVersionFileUpload -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -MobileAppContentFileId $ContentVersionFileId
            $file = WaitForFileProcessing $fileUri "AzureStorageUriRenewal"
            $sasUri = $file.azureStorageUri
            $sasUriRenewTime = $file.azureStorageUriExpirationDateTime.AddMinutes(-3)
            Write-Host "New SAS Uri renewal time: $sasUriRenewTime" -ForegroundColor Yellow
        }
    }

    $fileStream.Close()

    # Finalize the upload.
    Write-Host "Finalizing file upload..." -ForegroundColor Yellow
    FinalizeAzureStorageUpload $sasUri $ids | Out-Null
}

####################################################
# Function to generate encryption key
function GenerateKey {
    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aesProvider = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $aesProvider.GenerateKey()
        $aesProvider.Key
    }
    finally {
        if ($null -ne $aesProvider) { $aesProvider.Dispose(); }
        if ($null -ne $aes) { $aes.Dispose(); }
    }
}

####################################################
# Function to generate HMAC key
function GenerateIV {
    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.IV
    }
    finally {
        if ($null -ne $aes) { $aes.Dispose(); }
    }
}

####################################################
# Function to create the encrypted target file compute HMAC value, and return the HMAC value
function EncryptFileWithIV($sourceFile, $targetFile, $encryptionKey, $hmacKey, $initializationVector) {
    $bufferBlockSize = 1024 * 4
    $computedMac = $null

    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256
        $hmacSha256.Key = $hmacKey
        $hmacLength = $hmacSha256.HashSize / 8

        $buffer = New-Object byte[] $bufferBlockSize
        $bytesRead = 0

        $targetStream = [System.IO.File]::Open($targetFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
        $targetStream.Write($buffer, 0, $hmacLength + $initializationVector.Length)

        try {
            $encryptor = $aes.CreateEncryptor($encryptionKey, $initializationVector)
            $sourceStream = [System.IO.File]::Open($sourceFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream -ArgumentList @($targetStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)

            $targetStream = $null
            while (($bytesRead = $sourceStream.Read($buffer, 0, $bufferBlockSize)) -gt 0) {
                $cryptoStream.Write($buffer, 0, $bytesRead)
                $cryptoStream.Flush()
            }
            $cryptoStream.FlushFinalBlock()
        }
        finally {
            if ($null -ne $cryptoStream) { $cryptoStream.Dispose(); }
            if ($null -ne $sourceStream) { $sourceStream.Dispose(); }
            if ($null -ne $encryptor) { $encryptor.Dispose(); }
        }

        try {
            $finalStream = [System.IO.File]::Open($targetFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)
            $finalStream.Seek($hmacLength, [System.IO.SeekOrigin]::Begin) > $null
            $finalStream.Write($initializationVector, 0, $initializationVector.Length)
            $finalStream.Seek($hmacLength, [System.IO.SeekOrigin]::Begin) > $null
            $hmac = $hmacSha256.ComputeHash($finalStream)
            $computedMac = $hmac
            $finalStream.Seek(0, [System.IO.SeekOrigin]::Begin) > $null
            $finalStream.Write($hmac, 0, $hmac.Length)
        }
        finally {
            if ($null -ne $finalStream) { $finalStream.Dispose(); }
        }
    }
    finally {
        if ($null -ne $targetStream) { $targetStream.Dispose(); }
        if ($null -ne $aes) { $aes.Dispose(); }
    }

    $computedMac
}

####################################################
# Function to encrypt file and return encryption info
function EncryptFile($sourceFile, $targetFile) {
    $encryptionKey = GenerateKey
    $hmacKey = GenerateKey
    $initializationVector = GenerateIV

    # Create the encrypted target file and compute the HMAC value.
    $mac = EncryptFileWithIV $sourceFile $targetFile $encryptionKey $hmacKey $initializationVector

    # Compute the SHA256 hash of the source file and convert the result to bytes.
    $fileDigest = (Get-FileHash $sourceFile -Algorithm SHA256).Hash
    $fileDigestBytes = New-Object byte[] ($fileDigest.Length / 2)
    for ($i = 0; $i -lt $fileDigest.Length; $i += 2) {
        $fileDigestBytes[$i / 2] = [System.Convert]::ToByte($fileDigest.Substring($i, 2), 16)
    }

    # Return an object that will serialize correctly to the file commit Graph API.
    $encryptionInfo = @{}
    $encryptionInfo.encryptionKey = [System.Convert]::ToBase64String($encryptionKey)
    $encryptionInfo.macKey = [System.Convert]::ToBase64String($hmacKey)
    $encryptionInfo.initializationVector = [System.Convert]::ToBase64String($initializationVector)
    $encryptionInfo.mac = [System.Convert]::ToBase64String($mac)
    $encryptionInfo.profileIdentifier = "ProfileVersion1"
    $encryptionInfo.fileDigest = [System.Convert]::ToBase64String($fileDigestBytes)
    $encryptionInfo.fileDigestAlgorithm = "SHA256"

    $fileEncryptionInfo = @{}
    $fileEncryptionInfo.fileEncryptionInfo = $encryptionInfo
    $fileEncryptionInfo
}

####################################################
# Function to wait for file processing to complete by polling the file upload state
function WaitForFileProcessing($fileUri, $stage) {
    $attempts = 120
    $waitTimeInSeconds = 2
    $successState = "$($stage)Success"
    $renewalSuccessState = "$($stage)RenewalSuccess"
    $renewalPendingState = "$($stage)RenewalPending"
    $pendingState = "$($stage)Pending"

    $file = $null
    while ($attempts -gt 0) {
        $file = Invoke-MgGraphRequest -Method GET -Uri $fileUri
        if ($file.uploadState -eq $successState -or $file.uploadState -eq $renewalSuccessState -or $file.uploadState -eq $renewalPendingState) {
            break
        }
        elseif ($file.uploadState -ne $pendingState -and $file.uploadState -ne $renewalPendingState) {
            throw "File upload state is not success: $($file.uploadState)"
        }

        Start-Sleep $waitTimeInSeconds
        $attempts--
    }

    if ($null -eq $file) {
        throw "File request did not complete in the allotted time."
    }
    $file
}

####################################################
# Function to generate body for mobileAppContentFile
function GetAppFileBody($name, $size, $sizeEncrypted, $manifest) {
    $body = @{ "@odata.type" = "#microsoft.graph.macOSPkgApp" }
    $body.name = $name
    $body.size = $size
    $body.sizeEncrypted = $sizeEncrypted
    $body.manifest = $manifest
    $body
}

####################################################
# Function to generate body for commit action
function GetAppCommitBody($contentVersionId, $LobType) {
    $body = @{ "@odata.type" = "#$LobType" }
    $body.committedContentVersion = $contentVersionId
    $body
}

#Function to encode the pre and post install scripts in base64
function Convert-ScriptToBase64($scriptPath) {
    $script = Get-Content $scriptPath -Raw
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($script)
    $encoded = [System.Convert]::ToBase64String($bytes)
    return $encoded
}

####################################################
# Function to generate body for Intune mobileapp
function New-macOSAppBody() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$displayName,
        [Parameter(Mandatory = $true)]
        [string]$Publisher,
        [Parameter(Mandatory = $false)]
        [string]$Description,
        [Parameter(Mandatory = $true)]
        [string]$fileName,
        [Parameter(Mandatory = $true)]
        [string]$primaryBundleId,
        [Parameter(Mandatory = $true)]
        [string]$primaryBundleVersion,
        [Parameter(Mandatory = $true)]
        [hashtable[]]$includedApps,
        [Parameter(Mandatory = $false)]
        [hashtable]$minimumSupportedOperatingSystem,
        [Parameter(Mandatory = $true)]
        [bool]$ignoreVersionDetection,
        [Parameter(Mandatory = $false)]
        [string]$preInstallScriptPath,
        [Parameter(Mandatory = $false)]
        [string]$postInstallScriptPath
    )

    $body = @{ "@odata.type" = "#microsoft.graph.macOSPkgApp" }
    $body.isFeatured = $false
    $body.categories = @()
    $body.displayName = $displayName
    $body.publisher = $publisher
    $body.description = $description
    $body.fileName = $fileName
    $body.informationUrl = ""
    $body.privacyInformationUrl = ""
    $body.developer = ""
    $body.notes = ""
    $body.owner = ""
    $body.primaryBundleId = $primaryBundleId
    $body.primaryBundleVersion = $primaryBundleVersion
    $body.includedApps = $includedApps
    $body.ignoreVersionDetection = $ignoreVersionDetection

    if ($null -eq $minimumSupportedOperatingSystem) {
        $body.minimumSupportedOperatingSystem = @{ v10_13 = $true }
    }
    else {
        $body.minimumSupportedOperatingSystem = $minimumSupportedOperatingSystem
    }

    if ($preInstallScriptPath) {
        $body.preInstallScript = @{
            scriptContent = Convert-ScriptToBase64($preInstallScriptPath)
        }
    }
    else {
        $body.preInstallScript = $null
    }

    if ($postInstallScriptPath) {
        $body.postInstallScript = @{
            scriptContent = Convert-ScriptToBase64($postInstallScriptPath)
        }
    }
    else {
        $body.postInstallScript = $null
    }
    
    return $body
}
