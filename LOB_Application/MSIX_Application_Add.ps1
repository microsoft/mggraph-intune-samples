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
Uploads an MSIX/AppX line-of-business app (windowsUniversalAppX) to Intune.

.DESCRIPTION
This function uploads an MSIX/AppX line-of-business app to Intune.

Unlike a Win32 (.intunewin) app, an .msix/.appx package is NOT pre-encrypted and does NOT contain a
detection.xml. Instead, the script:
  1. Extracts the package manifest (AppxManifest.xml, or AppxBundleManifest.xml for *.msixbundle / *.appxbundle).
  2. Parses the package Identity (Name, Publisher, Version, ProcessorArchitecture, ResourceId).
  3. Computes the Identity Publisher Hash from the Identity Publisher string (the same hash that forms the
     last segment of a package family name).
  4. Encrypts the package locally (AES + HMAC-SHA256) and uploads the encrypted copy to Azure Storage.
  5. Commits the encrypted file and publishes the windowsUniversalAppX app.

.PARAMETER SourceFile
The path to the .msix, .msixbundle, .appx, or .appxbundle file.

.PARAMETER displayName
The display name of the app. If not specified, the script uses the package DisplayName (or Identity Name) from the manifest.

.PARAMETER publisher
The publisher of the app. If not specified, the script uses the package PublisherDisplayName (or Identity Publisher) from the manifest.

.PARAMETER description
The description of the app. If not specified, the script uses the display name.

.PARAMETER minimumSupportedOperatingSystem
The minimum supported operating system for the app, as a windowsMinimumOperatingSystem hashtable.
Valid keys for windowsUniversalAppX are 'v8_0', 'v8_1', and 'v10_0'. Defaults to @{ v10_0 = $true }.

.PARAMETER IconFile
The path to an image file (.png, .jpg, .jpeg, or .gif) to use as the app icon. The image is converted to a mimeContent object and uploaded as the app's largeIcon. Optional.

.EXAMPLE
# Uploads an .msix app to Intune, letting the script parse the display name, publisher, and identity from the package.
Invoke-MSIXAppUpload -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.0.0.0_x64.msix"

.EXAMPLE
# Uploads an .msix app with an explicit display name, publisher, description, and app icon.
Invoke-MSIXAppUpload -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.0.0.0_x64.msix" -displayName "Contoso Demo App" -publisher "Contoso" -description "Contoso Demo App (MSIX)" -IconFile "C:\IntuneApps\Contoso\icon.png"

.EXAMPLE
# Uploads an .msixbundle app and overrides the minimum supported operating system.
Invoke-MSIXAppUpload -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.0.0.0_x64.msixbundle" -displayName "Contoso Demo App" -minimumSupportedOperatingSystem @{ v10_0 = $true }
#>
function Invoke-MSIXAppUpload {
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFile,

        [parameter(Mandatory = $false, Position = 2)]
        [string]$displayName,

        [parameter(Mandatory = $false, Position = 3)]
        [string]$publisher,

        [parameter(Mandatory = $false, Position = 4)]
        [string]$description,

        [parameter(Mandatory = $false, Position = 5)]
        [hashtable]$minimumSupportedOperatingSystem,

        [parameter(Mandatory = $false, Position = 6)]
        [string]$IconFile
    )

    # Temp encrypted copy of the package (created during the encryption step, removed in the finally block)
    $tempFile = $null

    try {
        # Check if the source file exists and has a supported extension
        Write-Host "Testing if SourceFile '$SourceFile' Path is valid..." -ForegroundColor Yellow
        Test-SourceFile "$SourceFile"

        $Ext = [System.IO.Path]::GetExtension("$SourceFile").ToLower()
        if ($Ext -notin '.msix', '.msixbundle', '.appx', '.appxbundle') {
            throw "Unsupported file type '$Ext'. Supported types are .msix, .msixbundle, .appx, and .appxbundle."
        }

        Write-Host "Parsing the package manifest..." -ForegroundColor Yellow

        # Extract and parse the package manifest to get the identity metadata that Intune requires.
        # This is the key difference vs. Win32: there is no detection.xml, so the metadata comes from
        # AppxManifest.xml (or AppxBundleManifest.xml for bundles).
        $AppInfo = Get-MSIXAppInformation -SourceFile "$SourceFile"

        Write-Host "Package identity parsed from manifest:" -ForegroundColor Gray
        Write-Host "  Identity Name        : $($AppInfo.IdentityName)" -ForegroundColor Gray
        Write-Host "  Identity Version     : $($AppInfo.IdentityVersion)" -ForegroundColor Gray
        Write-Host "  Identity Publisher   : $($AppInfo.IdentityPublisher)" -ForegroundColor Gray
        Write-Host "  Publisher Hash       : $($AppInfo.IdentityPublisherHash)" -ForegroundColor Gray
        Write-Host "  Architecture(s)      : $($AppInfo.ApplicableArchitectures)" -ForegroundColor Gray
        Write-Host "  Is Bundle            : $($AppInfo.IsBundle)" -ForegroundColor Gray

        # Resolve the values that can be overridden by the caller, otherwise fall back to the manifest.
        if (!$displayName) { $displayName = if ($AppInfo.DisplayName) { $AppInfo.DisplayName } else { $AppInfo.IdentityName } }
        if (!$publisher) { $publisher = if ($AppInfo.PublisherDisplayName) { $AppInfo.PublisherDisplayName } else { $AppInfo.IdentityPublisher } }
        if (!$description) { $description = $displayName }
        if (!$minimumSupportedOperatingSystem) { $minimumSupportedOperatingSystem = @{ "v10_0" = $true } }

        $FileName = [System.IO.Path]::GetFileName("$SourceFile")

        # Build the windowsUniversalAppX app body
        Write-Host "Creating JSON data to pass to the service..." -ForegroundColor Yellow
        $mobileAppBody = New-MSIXAppBody `
            -displayName "$displayName" `
            -publisher "$publisher" `
            -description "$description" `
            -fileName "$FileName" `
            -identityName $AppInfo.IdentityName `
            -identityPublisherHash $AppInfo.IdentityPublisherHash `
            -identityResourceIdentifier $AppInfo.IdentityResourceIdentifier `
            -identityVersion $AppInfo.IdentityVersion `
            -isBundle $AppInfo.IsBundle `
            -applicableArchitectures $AppInfo.ApplicableArchitectures `
            -applicableDeviceTypes "desktop" `
            -minimumSupportedOperatingSystem $minimumSupportedOperatingSystem

        # Add the app icon (largeIcon) if an icon file was provided
        if ($IconFile) {
            Write-Host "Adding app icon from '$IconFile'..." -ForegroundColor Yellow
            $mobileAppBody.Add("largeIcon", (New-IntuneAppIcon -IconFile $IconFile))
        }

        # Create the application in Intune and get the application ID
        Write-Host "Creating application in Intune..." -ForegroundColor Yellow
        $MobileApp = New-MgDeviceAppManagementMobileApp -BodyParameter ($mobileAppBody | ConvertTo-Json)
        $mobileAppId = $MobileApp.id

        # Create a new content version for the application
        Write-Host "Creating Content Version in the service for the application..." -ForegroundColor Yellow
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

        # Update the application with the committed content version
        $params = @{
            "@odata.type"           = "#microsoft.graph.windowsUniversalAppX"
            committedContentVersion = "$ContentVersionId"
        }
        Write-Host "Updating the application with the new content version..." -ForegroundColor Yellow
        Update-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId -BodyParameter ($params | ConvertTo-Json)

        # Return the application details
        Write-Host "Application created successfully." -ForegroundColor Green
        Write-Host "Application Details:"
        Get-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId | Format-List
    }
    catch {
        Write-Host -ForegroundColor Red "Aborting with exception: $($_.Exception.ToString())"

        # In the event that the creation of the app record in Intune succeeded, but processing/file upload failed, you can remove the comment block around the code below to delete the app record.
        # This will allow you to re-run the script without having to manually delete the incomplete app record.
        # Note: This will only work if the app record was successfully created in Intune.

        <#
        if ($mobileAppId) {
            Write-Host "Removing the incomplete application record from Intune..." -ForegroundColor Yellow
            Remove-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId
        }
        #>
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
Extracts and parses the manifest of an MSIX/AppX package.

.DESCRIPTION
This function opens an .msix/.appx (or .msixbundle/.appxbundle) package, extracts the package manifest,
and returns a hashtable of the identity metadata required to create a windowsUniversalAppX app in Intune.

.PARAMETER SourceFile
The path to the .msix, .msixbundle, .appx, or .appxbundle file.

.EXAMPLE
$AppInfo = Get-MSIXAppInformation -SourceFile "C:\IntuneApps\Contoso\Contoso.DemoApp_1.0.0.0_x64.msix"
#>
function Get-MSIXAppInformation() {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFile
    )

    $Ext = [System.IO.Path]::GetExtension("$SourceFile").ToLower()
    $IsBundle = ($Ext -eq '.msixbundle' -or $Ext -eq '.appxbundle')
    $ManifestName = if ($IsBundle) { 'AppxBundleManifest.xml' } else { 'AppxManifest.xml' }

    # Read the manifest XML out of the package (an .msix/.appx is a ZIP archive)
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$SourceFile")
    try {
        $entry = $zip.Entries | Where-Object { $_.FullName -ieq $ManifestName -or $_.Name -ieq $ManifestName } | Select-Object -First 1
        if (!$entry) {
            throw "Could not find '$ManifestName' in '$SourceFile'. The file may not be a valid MSIX/AppX package."
        }
        $reader = New-Object System.IO.StreamReader($entry.Open())
        $ManifestXml = $reader.ReadToEnd()
        $reader.Close()
    }
    finally {
        $zip.Dispose()
    }

    [xml]$Manifest = $ManifestXml

    # The Identity element lives under <Bundle> for bundles and <Package> for single packages
    if ($IsBundle) {
        $Identity = $Manifest.Bundle.Identity
        # A bundle's identity has no ProcessorArchitecture; collect the distinct architectures of the
        # contained packages instead.
        $Architectures = @($Manifest.Bundle.Packages.Package |
                Where-Object { $_.Architecture } |
                ForEach-Object { ConvertTo-WindowsArchitecture $_.Architecture } |
                Select-Object -Unique)
        if (!$Architectures -or $Architectures.Count -eq 0) { $Architectures = @("neutral") }
        $ApplicableArchitectures = ($Architectures -join ",")
        $DisplayName = $null
        $PublisherDisplayName = $null
    }
    else {
        $Identity = $Manifest.Package.Identity
        $ApplicableArchitectures = ConvertTo-WindowsArchitecture $Identity.ProcessorArchitecture
        $DisplayName = $Manifest.Package.Properties.DisplayName
        $PublisherDisplayName = $Manifest.Package.Properties.PublisherDisplayName
    }

    # The identity Publisher (e.g. "CN=Contoso") is hashed to produce the Identity Publisher Hash that
    # Intune stores (the same hash used as the last segment of a package family name).
    $PublisherHash = Get-MSIXPublisherHash -Publisher $Identity.Publisher

    return @{
        IdentityName               = $Identity.Name
        IdentityVersion            = $Identity.Version
        IdentityPublisher          = $Identity.Publisher
        IdentityPublisherHash      = $PublisherHash
        IdentityResourceIdentifier = if ($Identity.ResourceId) { $Identity.ResourceId } else { "" }
        ApplicableArchitectures    = $ApplicableArchitectures
        IsBundle                   = $IsBundle
        DisplayName                = $DisplayName
        PublisherDisplayName       = $PublisherDisplayName
    }
}

<#
.SYNOPSIS
Computes the Identity Publisher Hash for an MSIX/AppX publisher string.

.DESCRIPTION
This function computes the publisher hash that Intune stores in the windowsUniversalAppX
identityPublisherHash property. This is the same hash that forms the last segment of a package family
name (for example, the "8wekyb3d8bbwe" in a Microsoft package family name).

The algorithm is:
  1. UTF-16LE encode the publisher string.
  2. Compute its SHA-256 hash.
  3. Take the first 8 bytes (64 bits) and pad to 65 bits.
  4. Encode each 5-bit group using the alphabet "0123456789abcdefghjkmnpqrstvwxyz".

.PARAMETER Publisher
The Identity Publisher string from the manifest (for example, "CN=Contoso").

.EXAMPLE
Get-MSIXPublisherHash -Publisher "CN=Contoso"
#>
function Get-MSIXPublisherHash() {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Publisher
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hashBytes = $sha256.ComputeHash([System.Text.Encoding]::Unicode.GetBytes($Publisher))
    }
    finally {
        $sha256.Dispose()
    }

    # Build a binary string from the first 8 bytes (64 bits), then pad to 65 bits so it splits into 13 groups of 5 bits.
    $binary = -join ($hashBytes[0..7] | ForEach-Object { [System.Convert]::ToString($_, 2).PadLeft(8, '0') })
    $binary = $binary.PadRight(65, '0')

    $encoding = '0123456789abcdefghjkmnpqrstvwxyz'
    $result = New-Object System.Text.StringBuilder
    for ($i = 0; $i -lt 65; $i += 5) {
        $index = [System.Convert]::ToInt32($binary.Substring($i, 5), 2)
        [void]$result.Append($encoding[$index])
    }

    return $result.ToString()
}

<#
.SYNOPSIS
Maps an MSIX/AppX processor architecture to a Graph windowsArchitecture value.

.DESCRIPTION
This function maps the ProcessorArchitecture/Architecture value from a package manifest to the
corresponding value used by the windowsUniversalAppX applicableArchitectures property.

.PARAMETER Architecture
The processor architecture from the manifest (for example, "x64", "x86", "arm", "arm64", or "neutral").

.EXAMPLE
ConvertTo-WindowsArchitecture "x64"
#>
function ConvertTo-WindowsArchitecture() {
    param
    (
        [parameter(Mandatory = $false)]
        [string]$Architecture
    )

    switch ("$Architecture".ToLower()) {
        "x64" { "x64" }
        "x86" { "x86" }
        "arm" { "arm" }
        "arm64" { "arm64" }
        "neutral" { "neutral" }
        default { "neutral" }
    }
}

<#
.SYNOPSIS
Constructs the JSON body for a windowsUniversalAppX (MSIX/AppX) app.

.DESCRIPTION
This function builds the hashtable body used to create a windowsUniversalAppX app in Intune.

.EXAMPLE
$body = New-MSIXAppBody -displayName "Contoso Demo App" -publisher "Contoso" -description "Contoso Demo App" -fileName "Contoso.DemoApp_1.0.0.0_x64.msix" -identityName "Contoso.DemoApp" -identityPublisherHash "ab82cd0xyz" -identityResourceIdentifier "" -identityVersion "1.0.0.0" -isBundle $false -applicableArchitectures "x64" -applicableDeviceTypes "desktop" -minimumSupportedOperatingSystem @{ v10_0 = $true }
#>
function New-MSIXAppBody() {
    param
    (
        [parameter(Mandatory = $true)]
        [string]$displayName,

        [parameter(Mandatory = $true)]
        [string]$publisher,

        [parameter(Mandatory = $true)]
        [string]$description,

        [parameter(Mandatory = $true)]
        [string]$fileName,

        [parameter(Mandatory = $true)]
        [string]$identityName,

        [parameter(Mandatory = $true)]
        [string]$identityPublisherHash,

        [parameter(Mandatory = $false)]
        [string]$identityResourceIdentifier,

        [parameter(Mandatory = $true)]
        [string]$identityVersion,

        [parameter(Mandatory = $true)]
        [bool]$isBundle,

        [parameter(Mandatory = $true)]
        [string]$applicableArchitectures,

        [parameter(Mandatory = $false)]
        [string]$applicableDeviceTypes = "desktop",

        [parameter(Mandatory = $true)]
        [hashtable]$minimumSupportedOperatingSystem
    )

    $body = @{ "@odata.type" = "#microsoft.graph.windowsUniversalAppX" }
    $body.displayName = $displayName
    $body.publisher = $publisher
    $body.description = $description
    $body.fileName = $fileName
    $body.developer = ""
    $body.notes = ""
    $body.owner = ""
    $body.isFeatured = $false
    $body.informationUrl = $null
    $body.privacyInformationUrl = $null
    $body.applicableArchitectures = $applicableArchitectures
    $body.applicableDeviceTypes = $applicableDeviceTypes
    $body.identityName = $identityName
    $body.identityPublisherHash = $identityPublisherHash
    $body.identityResourceIdentifier = $identityResourceIdentifier
    $body.identityVersion = $identityVersion
    $body.isBundle = $isBundle
    $body.minimumSupportedOperatingSystem = $minimumSupportedOperatingSystem

    return $body
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
