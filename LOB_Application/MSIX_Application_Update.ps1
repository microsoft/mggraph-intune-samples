#requires -module Microsoft.Graph.Devices.CorporateManagement
#requires -module Microsoft.Graph.Authentication

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0
The PowerShell SDK supports two types of authentication: delegated access, and app-only access.
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal
#>

<#
.SYNOPSIS
Updates an MSIX/AppX line-of-business app (windowsUniversalAppX) in Intune.

.DESCRIPTION
This function updates an existing MSIX/AppX line-of-business app in Intune by uploading a new package as a
new content version. The new .msix/.appx is encrypted locally, uploaded to Azure Storage, and committed,
then the app is pointed at the new content version. A windowsUniversalAppX app's package identity
(identityName, identityPublisherHash, identityVersion, isBundle, applicableArchitectures, etc.) is read-only
after creation, so an update changes only the package content plus any editable metadata (display name,
publisher, description, icon).

Note: Intune requires that an updated windowsUniversalAppX package has the same Identity Name and Publisher
as the existing app. Typically only the Identity Version increases between updates.

.PARAMETER AppId
The ID of the Intune windowsUniversalAppX app to update.

.PARAMETER UpdateAppContentOnly
If $true, only the app package content is updated and other app properties (e.g. Name, identity, etc.) are not updated.

.PARAMETER SourceFile
The path to the .msix, .msixbundle, .appx, or .appxbundle file.

.PARAMETER displayName
The new display name of the app. Only applied when -UpdateAppContentOnly is $false. If omitted, the existing display name is left unchanged.

.PARAMETER publisher
The new publisher of the app. Only applied when -UpdateAppContentOnly is $false. If omitted, the existing publisher is left unchanged.

.PARAMETER description
The new description of the app. Only applied when -UpdateAppContentOnly is $false. If omitted, the existing description is left unchanged.

.PARAMETER minimumSupportedOperatingSystem
The minimum supported operating system for the app, as a windowsMinimumOperatingSystem hashtable.
Valid keys for windowsUniversalAppX are 'v8_0', 'v8_1', and 'v10_0'. Only applied when -UpdateAppContentOnly is $false and a value is supplied.

.PARAMETER IconFile
The path to an image file (.png, .jpg, .jpeg, or .gif) to use as the app icon. The image is converted to a mimeContent object and uploaded as the app's largeIcon. Optional, and applied whether or not -UpdateAppContentOnly is used.

.EXAMPLE
# Updates only the package content of an existing MSIX app.
Invoke-MSIXAppUpdate -AppId "12345678-1234-1234-1234-123456789012" -UpdateAppContentOnly $true -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.1.0.0_x64.msix"

.EXAMPLE
# Updates the package content and app properties of an existing MSIX app.
Invoke-MSIXAppUpdate -AppId "12345678-1234-1234-1234-123456789012" -UpdateAppContentOnly $false -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.1.0.0_x64.msix" -displayName "Contoso Demo App" -publisher "Contoso" -description "Version 1.1.0.0"

.EXAMPLE
# Updates only the app icon of an existing MSIX app (still requires a source package for the new content version).
Invoke-MSIXAppUpdate -AppId "12345678-1234-1234-1234-123456789012" -UpdateAppContentOnly $true -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.0.0.0_x64.msix" -IconFile "C:\IntuneApps\Contoso\icon.png"
#>
function Invoke-MSIXAppUpdate {
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$AppId,

        [parameter(Mandatory = $true, Position = 2)]
        [bool]$UpdateAppContentOnly,

        [parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFile,

        [parameter(Mandatory = $false, Position = 4)]
        [string]$displayName,

        [parameter(Mandatory = $false, Position = 5)]
        [string]$publisher,

        [parameter(Mandatory = $false, Position = 6)]
        [string]$description,

        [parameter(Mandatory = $false, Position = 7)]
        [hashtable]$minimumSupportedOperatingSystem,

        [parameter(Mandatory = $false, Position = 8)]
        [string]$IconFile
    )

    # Temp encrypted copy of the package (created during the encryption step, removed in the finally block)
    $tempFile = $null

    try {
        # Check if the app exists
        $MobileApp = Get-MgDeviceAppManagementMobileApp -MobileAppId $AppId

        if ($null -eq $MobileApp) {
            Write-Host "Application with ID '$AppId' does not exist in Intune." -ForegroundColor Red
            break
        }

        Write-Host "Application found..." -ForegroundColor Yellow
        $mobileAppId = $MobileApp.id

        # Check if the source file exists and has a supported extension
        Write-Host "Testing if SourceFile '$SourceFile' Path is valid..." -ForegroundColor Yellow
        Test-SourceFile "$SourceFile"

        $Ext = [System.IO.Path]::GetExtension("$SourceFile").ToLower()
        if ($Ext -notin '.msix', '.msixbundle', '.appx', '.appxbundle') {
            throw "Unsupported file type '$Ext'. Supported types are .msix, .msixbundle, .appx, and .appxbundle."
        }

        $FileName = [System.IO.Path]::GetFileName("$SourceFile")

        # Note: a windowsUniversalAppX app's package identity (identityName, identityPublisherHash,
        # identityVersion, isBundle, applicableArchitectures, etc.) is read-only after creation - the
        # service re-derives it from the newly committed package content. An update therefore only changes
        # the package content plus any editable metadata (display name, publisher, description, icon).

        # Create a new content version for the application
        Write-Host "Creating Content Version in the service for the updated application..." -ForegroundColor Yellow
        $ContentVersion = New-MgDeviceAppManagementMobileAppAsWindowsUniversalAppXContentVersion -MobileAppId $mobileAppId -BodyParameter @{}
        $ContentVersionId = $ContentVersion.id

        # Encrypt a copy of the package. Unlike a .intunewin file (which is already encrypted), the .msix is
        # a raw file, so the script generates the encryption keys and computes the file digest itself.
        Write-Host "Encrypting a copy of the package '$SourceFile'..." -ForegroundColor Yellow
        $tempFile = [System.IO.Path]::Combine([System.IO.Path]::GetDirectoryName("$SourceFile"), [System.IO.Path]::GetFileNameWithoutExtension("$SourceFile") + "_" + [guid]::NewGuid().ToString() + "_temp.bin")
        $fileEncryptionInfo = EncryptFile "$SourceFile" "$tempFile"

        [int64]$Size = (Get-Item "$SourceFile").Length
        $EncrySize = (Get-Item "$tempFile").Length

        # Create a new file entry in Azure for the upload. Unlike Win32/macOS content files, a
        # windowsUniversalAppX content file requires a (non-null) manifest. For MSIX/AppX the service only
        # requires the base64-encoded file name here (the rich identity metadata is supplied on the app body).
        $encodedManifest = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($FileName))
        $fileBody = GetAppFileBody "$FileName" $Size $EncrySize $encodedManifest
        Write-Host "Creating a new file entry in Azure for the upload..." -ForegroundColor Yellow
        $ContentVersionFile = New-MgDeviceAppManagementMobileAppAsWindowsUniversalAppXContentVersionFile -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -BodyParameter ($fileBody | ConvertTo-Json)
        $ContentVersionFileId = $ContentVersionFile.id

        # Get the file URI for the upload
        $fileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$mobileAppId/microsoft.graph.windowsUniversalAppX/contentVersions/$ContentVersionId/files/$ContentVersionFileId"

        # Wait for the Azure Storage SAS URI to be created
        Write-Host "Waiting for the file entry SAS URI to be created..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "AzureStorageUriRequest"

        # Upload the encrypted file to Azure Storage
        Write-Host "Uploading the file to Azure Storage..." -ForegroundColor Yellow
        [UInt64]$BlockSizeMB = 4
        UploadFileToAzureStorage $file.azureStorageUri "$tempFile" $BlockSizeMB

        # Commit the file to the service using the encryption information
        Write-Host "Committing the file to the service..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        Invoke-MgCommitDeviceAppManagementMobileAppMicrosoftGraphWindowsUniversalAppXContentVersionFile -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -MobileAppContentFileId $ContentVersionFileId -BodyParameter ($fileEncryptionInfo | ConvertTo-Json)

        # Wait for the file to be processed
        Write-Host "Waiting for the file to be processed..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "CommitFile"

        # Build the body that points the app at the new committed content version. Only editable metadata is
        # included; the package identity is read-only and is re-derived from the committed content. Editable
        # fields are set only when supplied so an update never overwrites the existing display name,
        # publisher, or description with values that were not requested.
        $params = @{
            "@odata.type"           = "#microsoft.graph.windowsUniversalAppX"
            committedContentVersion = "$ContentVersionId"
        }

        if (-not $UpdateAppContentOnly) {
            if ($displayName) { $params.displayName = $displayName }
            if ($publisher) { $params.publisher = $publisher }
            if ($description) { $params.description = $description }
            if ($minimumSupportedOperatingSystem) { $params.minimumSupportedOperatingSystem = $minimumSupportedOperatingSystem }
        }

        # Add the app icon (largeIcon) if an icon file was provided
        if ($IconFile) {
            Write-Host "Adding app icon from '$IconFile'..." -ForegroundColor Yellow
            $params["largeIcon"] = New-IntuneAppIcon -IconFile $IconFile
        }

        # Update the application with the new content version
        Write-Host "Updating the application with the new content version..." -ForegroundColor Yellow
        Update-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId -BodyParameter ($params | ConvertTo-Json)

        # Return the application details
        Write-Host "Application updated successfully:" -ForegroundColor Green
        Get-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId | Format-List
    }
    catch {
        Write-Host -ForegroundColor Red "Aborting with exception: $($_.Exception.ToString())"
        break
    }
    finally {
        # Clean up the temporary encrypted copy of the package
        if ($tempFile -and (Test-Path "$tempFile")) {
            Remove-Item -Path "$tempFile" -Force -ErrorAction SilentlyContinue
        }
    }
}

<#
.SYNOPSIS
Converts an image file to a mimeContent object for use as an app icon.

.DESCRIPTION
This function reads an image file from disk, base64-encodes its content, and returns a mimeContent hashtable that can be assigned to a mobileApp's largeIcon property. Supported image types are .png, .jpg, .jpeg, and .gif.

.PARAMETER IconFile
The path to the image file to use as the app icon.

.EXAMPLE
# Creates a mimeContent icon object from a .png file.
New-IntuneAppIcon -IconFile "C:\IntuneApps\Contoso\icon.png"
#>
function New-IntuneAppIcon() {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$IconFile
    )

    # Check the icon file exists
    if (!(Test-Path "$IconFile")) {
        Write-Host "Icon file '$IconFile' doesn't exist..." -ForegroundColor Red
        throw "Icon file not found: $IconFile"
    }

    # Determine the MIME type from the file extension
    $Extension = [System.IO.Path]::GetExtension("$IconFile").ToLower()
    switch ($Extension) {
        ".png" { $MimeType = "image/png" }
        ".jpg" { $MimeType = "image/jpeg" }
        ".jpeg" { $MimeType = "image/jpeg" }
        ".gif" { $MimeType = "image/gif" }
        default {
            Write-Host "Unsupported icon file type '$Extension'. Supported types are .png, .jpg, .jpeg, and .gif." -ForegroundColor Red
            throw "Unsupported icon file type: $Extension"
        }
    }

    # Read the image file and base64-encode its content
    $IconContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$IconFile"))

    # Construct and return the mimeContent object (used as the app's largeIcon)
    $Icon = @{
        "@odata.type" = "#microsoft.graph.mimeContent"
        "type"        = $MimeType
        "value"       = $IconContent
    }

    return $Icon
}

####################################################
# Function to test if the source file exists
Function Test-SourceFile() {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $SourceFile
    )
    try {
        if (!(Test-Path "$SourceFile")) {
            Write-Host
            Write-Host "Source File '$SourceFile' doesn't exist..." -ForegroundColor Red
            throw
        }
    }
    catch {
        Write-Host -ForegroundColor Red $_.Exception.Message
        Write-Host
        break
    }
}

####################################################
# Function to generate the AES encryption key
function GenerateKey {
    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aesProvider = New-Object System.Security.Cryptography.AesCryptoServiceProvider
        $aesProvider.GenerateKey()
        $aesProvider.Key
    }
    finally {
        if ($null -ne $aesProvider) { $aesProvider.Dispose() }
        if ($null -ne $aes) { $aes.Dispose() }
    }
}

####################################################
# Function to generate the AES initialization vector
function GenerateIV {
    try {
        $aes = [System.Security.Cryptography.Aes]::Create()
        $aes.IV
    }
    finally {
        if ($null -ne $aes) { $aes.Dispose() }
    }
}

####################################################
# Function to create the encrypted target file, compute the HMAC value, and return the HMAC value
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
            if ($null -ne $cryptoStream) { $cryptoStream.Dispose() }
            if ($null -ne $sourceStream) { $sourceStream.Dispose() }
            if ($null -ne $encryptor) { $encryptor.Dispose() }
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
            if ($null -ne $finalStream) { $finalStream.Dispose() }
        }
    }
    finally {
        if ($null -ne $targetStream) { $targetStream.Dispose() }
        if ($null -ne $aes) { $aes.Dispose() }
    }

    $computedMac
}

####################################################
# Function to encrypt the file and return the file encryption info needed to commit the file
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

    $file
}

####################################################
# Function that splits the source file into chunks and uploads them to the Azure Storage SAS URI location, then finalizes the upload
function UploadFileToAzureStorage($sasUri, $filepath, $blockSizeMB) {
    # Chunk size in MiB
    $chunkSizeInBytes = (1024 * 1024 * $blockSizeMB)

    # Read the whole file and find the total chunks.
    $fileStream = [System.IO.File]::OpenRead($filepath)
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
        $fileStream.Read($body, 0, $size) > $null

        Write-Progress -Activity "Uploading File to Azure Storage" -Status "Uploading chunk $cc of $chunks" -PercentComplete ($cc / $chunks * 100)
        $cc++

        UploadAzureStorageChunk $sasUri $id $body | Out-Null
        $chunk++
    }

    $fileStream.Close()
    Write-Progress -Completed -Activity "Uploading File to Azure Storage"

    # Finalize the upload.
    FinalizeAzureStorageUpload $sasUri $ids | Out-Null
}

####################################################
# Function to upload a chunk to Azure Storage
function UploadAzureStorageChunk($sasUri, $id, $body) {
    $uri = "$sasUri&comp=block&blockid=$id"
    $request = "PUT $uri"

    $headers = @{
        "x-ms-blob-type" = "BlockBlob"
        "Content-Type"   = "application/octet-stream"
    }

    try {
        Invoke-WebRequest -Headers $headers $uri -Method Put -Body $body | Out-Null
    }
    catch {
        Write-Host -ForegroundColor Red $request
        Write-Host -ForegroundColor Red $_.Exception.Message
        throw
    }
}

####################################################
# Function to finalize the Azure Storage upload by joining the uploaded chunks
function FinalizeAzureStorageUpload($sasUri, $ids) {
    $uri = "$sasUri&comp=blocklist"
    $request = "PUT $uri"

    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>'
    foreach ($id in $ids) {
        $xml += "<Latest>$id</Latest>"
    }
    $xml += '</BlockList>'

    $headers = @{
        "Content-Type" = "text/plain"
    }

    try {
        Invoke-WebRequest $uri -Method Put -Body $xml -Headers $headers | Out-Null
    }
    catch {
        Write-Host -ForegroundColor Red $request
        Write-Host -ForegroundColor Red $_.Exception.Message
        throw
    }
}

####################################################
# Function to create a new mobileAppContentFile body containing the file information
function GetAppFileBody($name, $size, $sizeEncrypted, $manifest) {
    $body = @{ "@odata.type" = "#microsoft.graph.mobileAppContentFile" }
    $body.name = $name
    $body.size = $size
    $body.sizeEncrypted = $sizeEncrypted
    $body.manifest = $manifest
    $body.isDependency = $false

    $body
}
