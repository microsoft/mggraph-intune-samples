Import-Module Microsoft.Graph.Devices.CorporateManagement

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0
The PowerShell SDK supports two types of authentication: delegated access, and app-only access.
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal
#>

#Path for temp copies of extracted .ipa files
$ExtractedPath = Join-Path -Path $env:TEMP -ChildPath ([System.IO.Path]::GetRandomFileName())

#Base URL for Graph API calls
$baseUrl = "https://graph.microsoft.com/v1.0/deviceAppManagement/"

$sleep = 30

####################################################
# Function to get the path to the IPA file
function Get-IpaPath {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [string]
        $Path
    )
    $IpaPath = Get-ChildItem -Path $Path -Filter *.ipa -Recurse -ErrorAction SilentlyContinue
    if (!$IpaPath) {
        throw "No IPA file found in $Path"
        return
    }
    return $IpaPath.FullName
}

####################################################
# Function that uploads a source file chunk to the Intune Service SAS URI location.
function UploadAzureStorageChunk($sasUri, $id, $body) {

    $uri = "$sasUri&comp=block&blockid=$id";
    $request = "PUT $uri";

    $headers = @{
        "x-ms-blob-type" = "BlockBlob";
        "Content-Type" = "application/octet-stream"
    };

    try {
        Invoke-WebRequest -Headers $headers $uri -Method Put -Body $body;
    }
    catch {
        Write-Host -ForegroundColor Red $request;
        Write-Host -ForegroundColor Red $_.Exception.Message;
        throw;
    }
}

####################################################
# Function that takes all the chunk ids and joins them back together to recreate the file
function FinalizeAzureStorageUpload($sasUri, $ids) {
    $uri = "$sasUri&comp=blocklist";
    $request = "PUT $uri";

    $xml = '<?xml version="1.0" encoding="utf-8"?><BlockList>';
    foreach ($id in $ids) {
        $xml += "<Latest>$id</Latest>";
    }
    $xml += '</BlockList>';

    if ($logRequestUris) { Write-Host $request; }
    if ($logContent) { Write-Host -ForegroundColor Gray $xml; }

    $headers = @{
        "Content-Type" = "text/plain"
    };

    try {
        Invoke-WebRequest $uri -Method Put -Body $xml -Headers $headers;
    }
    catch {
        Write-Host -ForegroundColor Red $request;
        Write-Host -ForegroundColor Red $_.Exception.Message;
        throw;
    }
}

####################################################
# Function that splits the source file into chunks and calls the upload to the Intune Service SAS URI location, and finalizes the upload
function UploadFileToAzureStorage($sasUri, $filepath, $blockSizeMB) {

    # Chunk size in MiB
    $chunkSizeInBytes = 1024 * 1024 * $blockSizeMB;

    # Read the whole file and find the total chunks.
    #[byte[]]$bytes = Get-Content $filepath -Encoding byte;
    # Using ReadAllBytes method as the Get-Content used alot of memory on the machine
    $fileStream = [System.IO.File]::OpenRead($filepath)
    $chunks = [Math]::Ceiling($fileStream.Length / $chunkSizeInBytes)

    # Upload each chunk.
    $ids = @();
    $cc = 1
    $chunk = 0
    while ($fileStream.Position -lt $fileStream.Length) {
        $id = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($chunk.ToString("0000")));
        $ids += $id;

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

####################################################
# Function to generate encryption key
function GenerateKey {
    try {
        $aes = [System.Security.Cryptography.Aes]::Create();
        $aesProvider = New-Object System.Security.Cryptography.AesCryptoServiceProvider;
        $aesProvider.GenerateKey();
        $aesProvider.Key;
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
        $aes = [System.Security.Cryptography.Aes]::Create();
        $aes.IV;
    }
    finally {
        if ($null -ne $aes) { $aes.Dispose(); }
    }
}

####################################################
# Function to create the encrypted target file compute HMAC value, and return the HMAC value
function EncryptFileWithIV($sourceFile, $targetFile, $encryptionKey, $hmacKey, $initializationVector) {
    $bufferBlockSize = 1024 * 4;
    $computedMac = $null;

    try {
        $aes = [System.Security.Cryptography.Aes]::Create();
        $hmacSha256 = New-Object System.Security.Cryptography.HMACSHA256;
        $hmacSha256.Key = $hmacKey;
        $hmacLength = $hmacSha256.HashSize / 8;

        $buffer = New-Object byte[] $bufferBlockSize;
        $bytesRead = 0;

        $targetStream = [System.IO.File]::Open($targetFile, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read);
        $targetStream.Write($buffer, 0, $hmacLength + $initializationVector.Length);

        try {
            $encryptor = $aes.CreateEncryptor($encryptionKey, $initializationVector);
            $sourceStream = [System.IO.File]::Open($sourceFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read);
            $cryptoStream = New-Object System.Security.Cryptography.CryptoStream -ArgumentList @($targetStream, $encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write);

            $targetStream = $null;
            while (($bytesRead = $sourceStream.Read($buffer, 0, $bufferBlockSize)) -gt 0) {
                $cryptoStream.Write($buffer, 0, $bytesRead);
                $cryptoStream.Flush();
            }
            $cryptoStream.FlushFinalBlock();
        }
        finally {
            if ($null -ne $cryptoStream) { $cryptoStream.Dispose(); }
            if ($null -ne $sourceStream) { $sourceStream.Dispose(); }
            if ($null -ne $encryptor) { $encryptor.Dispose(); }
        }

        try {
            $finalStream = [System.IO.File]::Open($targetFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::Read)

            $finalStream.Seek($hmacLength, [System.IO.SeekOrigin]::Begin) > $null;
            $finalStream.Write($initializationVector, 0, $initializationVector.Length);
            $finalStream.Seek($hmacLength, [System.IO.SeekOrigin]::Begin) > $null;

            $hmac = $hmacSha256.ComputeHash($finalStream);
            $computedMac = $hmac;

            $finalStream.Seek(0, [System.IO.SeekOrigin]::Begin) > $null;
            $finalStream.Write($hmac, 0, $hmac.Length);
        }
        finally {
            if ($null -ne $finalStream) { $finalStream.Dispose(); }
        }
    }
    finally {
        if ($null -ne $targetStream) { $targetStream.Dispose(); }
        if ($null -ne $aes) { $aes.Dispose(); }
    }

    $computedMac;
}

####################################################
# Function to encrypt file and return encryption info
function EncryptFile($sourceFile, $targetFile) {

    $encryptionKey = GenerateKey;
    $hmacKey = GenerateKey;
    $initializationVector = GenerateIV;

    # Create the encrypted target file and compute the HMAC value.
    $mac = EncryptFileWithIV $sourceFile $targetFile $encryptionKey $hmacKey $initializationVector;

    # Compute the SHA256 hash of the source file and convert the result to bytes.
    $fileDigest = (Get-FileHash $sourceFile -Algorithm SHA256).Hash;
    $fileDigestBytes = New-Object byte[] ($fileDigest.Length / 2);
    for ($i = 0; $i -lt $fileDigest.Length; $i += 2) {
        $fileDigestBytes[$i / 2] = [System.Convert]::ToByte($fileDigest.Substring($i, 2), 16);
    }

    # Return an object that will serialize correctly to the file commit Graph API.
    $encryptionInfo = @{};
    $encryptionInfo.encryptionKey = [System.Convert]::ToBase64String($encryptionKey);
    $encryptionInfo.macKey = [System.Convert]::ToBase64String($hmacKey);
    $encryptionInfo.initializationVector = [System.Convert]::ToBase64String($initializationVector);
    $encryptionInfo.mac = [System.Convert]::ToBase64String($mac);
    $encryptionInfo.profileIdentifier = "ProfileVersion1";
    $encryptionInfo.fileDigest = [System.Convert]::ToBase64String($fileDigestBytes);
    $encryptionInfo.fileDigestAlgorithm = "SHA256";

    $fileEncryptionInfo = @{};
    $fileEncryptionInfo.fileEncryptionInfo = $encryptionInfo;

    $fileEncryptionInfo;
}

####################################################
# Function to wait for file processing to complete by polling the file upload state
function WaitForFileProcessing($fileUri, $stage) {

    $attempts = 60;
    $waitTimeInSeconds = 1;
    $successState = "$($stage)Success";
    $pendingState = "$($stage)Pending";

    $file = $null;
    while ($attempts -gt 0) {
        $file = Invoke-MgGraphRequest -Method GET -Uri $fileUri;
        if ($file.uploadState -eq $successState) {
            break;
        }
        elseif ($file.uploadState -ne $pendingState) {
            throw "File upload state is not success: $($file.uploadState)";
        }

        Start-Sleep $waitTimeInSeconds;
        $attempts--;
    }

    if ($null -eq $file) {
        throw "File request did not complete in the allotted time.";
    }

    $file;

}

####################################################
# Function to generate body for mobileAppContentFile
function GetAppFileBody($name, $size, $sizeEncrypted, $manifest) {

    $body = @{ "@odata.type" = "#microsoft.graph.mobileAppContentFile" };
    $body.name = $name;
    $body.size = $size;
    $body.sizeEncrypted = $sizeEncrypted;
    $body.manifest = $manifest;

    $body;
}

####################################################
# Function to generate body for commit action
function GetAppCommitBody($contentVersionId, $LobType) {

    $body = @{ "@odata.type" = "#$LobType" };
    $body.committedContentVersion = $contentVersionId;
    $body;
}

####################################################
# Function to generate body for Intune mobileapp
function Get-iOSAppBody($displayName, $Publisher, $Description, $fileName) {
    $body = @{ "@odata.type" = "#microsoft.graph.iosLOBApp" };
    $body.applicableDeviceType = @{ "iPad" = $true; "iPhoneAndIPod" = $true }
    $body.isFeatured = $false;
    $body.categories = @();
    $body.displayName = $displayName;
    $body.publisher = $publisher;
    $body.description = $description;
    $body.fileName = $fileName;
    $body.informationUrl = $null;
    $body.privacyInformationUrl = $null;
    $body.developer = "";
    $body.notes = "";
    $body.owner = "";
    $body.bundleId = "";
    $body.buildNumber = "";
    $body.versionNumber = "";
    $body.expirationDateTime = "";

    if ($null -eq $minimumSupportedOperatingSystem) {
        $body.minimumSupportedOperatingSystem = @{ "v9_0" = $true };
    }
    else {
        $body.minimumSupportedOperatingSystem = $minimumSupportedOperatingSystem;
    }

    $ExtractedIPAMetadata = Get-IpaAppInfo $fileName
    $body.bundleId = $ExtractedIPAMetadata.BundleId;
    $body.buildNumber = $ExtractedIPAMetadata.BundleVersion;
    $body.versionNumber = $ExtractedIPAMetadata.BundleShortVersionString;
    $body.expirationDateTime = $ExtractedIPAMetadata.ExpirationDateTime;

    return $body
}

####################################################
# Function to extract the app information from the .ipa file
## If unable to extract the app information, the function will prompt the user to enter the app information manually
function Get-IpaAppInfo {
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$ipaFilePath
    )

    # Create a temporary directory to extract the app contents
    New-Item -ItemType Directory -Force -Path $ExtractedPath | Out-Null

    # Extract the .ipa file contents
    Expand-Archive -Path $ipaFilePath -DestinationPath $ExtractedPath

    # Find the first info.plist path  in the highest location of the directory structure

    $plistPath = (Get-ChildItem -Path $ExtractedPath -Recurse -Filter "info.plist" | Select-Object -ExpandProperty FullName)[0]

    if (-not $plistPath) {
        Write-Output "Error: Info.plist not found in the .ipa file."
    }

    # Parse the Info.plist file
    $plistData = Get-Content -Raw -Path $plistPath

    # Extract CFBundleIdentifier from $plistData using regex
    $bundleId = [regex]::Match($plistData, '(?<=<key>CFBundleIdentifier</key>\s*<string>)(.*?)(?=</string>)').Value
    if (($null -eq $bundleId) -or ($bundleId -eq "") ) {
        $bundleId = Read-Host -Prompt "Unable to extract the app's bundleId (CFBundleIdentifier). Please enter it manually"
    }

    # Extract CFBundleVersion from $plistData using regex
    $bundleVersion = [regex]::Match($plistData, '(?<=<key>CFBundleVersion</key>\s*<string>)(.*?)(?=</string>)').Value
    if (($null -eq $bundleVersion) -or ($bundleVersion -eq "")) {
        $bundleVersion = Read-Host -Prompt "Unable to extract the app's buildNumber (CFBundleVersion). Please enter it manually"
    }

    # Extract the CFBundleShortVersionString from $plistData using regex
    $bundleShortVersionString = [regex]::Match($plistData, '(?<=<key>CFBundleShortVersionString</key>\s*<string>)(.*?)(?=</string>)').Value
    if (($null -eq $bundleShortVersionString) -or ($bundleShortVersionString -eq "")) {
        $bundleShortVersionString = Read-Host -Prompt "Unable to extract the app's versionNumber (CFBundleShortVersionString). Please enter it manually"
    }

    # Check if embedded.mobileprovision file exists
    $MobileProvisionPath = Get-ChildItem -Path $ExtractedPath -Recurse -Filter 'embedded.mobileprovision' | Select-Object -ExpandProperty FullName
    if (!$MobileProvisionPath) {
        Write-Host  "The .ipa file does not contain an embedded.mobileprovision file."
    }

    # Read the contents of the embedded.mobileprovision file
    $MobileProvisionContent = Get-Content -Path $MobileProvisionPath -Raw

    # Extract the ExpirationDate value
    $ExpirationDateMatch = [regex]::Match($MobileProvisionContent, '<key>ExpirationDate<\/key>\s*<date>(.+)<\/date>')
    if (!$ExpirationDateMatch.Success) {
        Write-Host "The embedded.mobileprovision file does not contain an ExpirationDate key."
    }

    # Parse and validate the ExpirationDate value
    $ExpirationDateString = $ExpirationDateMatch.Groups[1].Value
    try {
        $ExpirationDate = [DateTime]::Parse($ExpirationDateString)
    }
    catch {
        Write-Host "The ExpirationDate key in the embedded.mobileprovision file is not a valid date."
    }

    if (($null -eq $ExpirationDate) -or ($ExpirationDate -eq "")) {
        $ExpirationDate = Read-Host -Prompt "Unable to extract the app's expiration date (ExpirationDate). Please enter it manually in the format yyyy-MM-ddTHH:mm:ssZ"
    }

    # Clean up the temporary directory
    Remove-Item -Path $ExtractedPath -Recurse -Force


    # Compare the ExpirationDate with the current date
    if ($ExpirationDate -lt (Get-Date)) {
        Write-Error "The ExpirationDate for this app ($ExpirationDate) has already passed." -ErrorAction Stop

    }
    # Return the extracted values
    return @{
        BundleId                 = $bundleId
        BundleVersion            = $bundleVersion
        BundleShortVersionString = $bundleShortVersionString
        ExpirationDateTime       = $ExpirationDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    }

}

####################################################
# Function the kicks off the iOS LOB app upload process by calling the previous functions in proper order
function Invoke-iOSLobAppUpload() {
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
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Description,
        [Parameter()]
        [UInt32]$BlockSizeMB = 1
    )
    try {

        # Check if the file exists and has a .ipa extension
        if (!(Test-Path $SourceFile) -or (Get-Item $SourceFile).Extension -ne '.ipa') {
            Write-Error "The provided path does not exist or is not an .ipa file."
            return
        }
        $LOBType = "microsoft.graph.iosLOBApp"

        # Creating temp file name from Source File path
        $tempFile = [System.IO.Path]::GetDirectoryName("$SourceFile") + "\" + [System.IO.Path]::GetFileNameWithoutExtension("$SourceFile") + "_temp.bin"

        # Creating filename variable from Source File Path
        $fileName = [System.IO.Path]::GetFileName("$SourceFile")

        Write-Host "Creating JSON data to pass to the service..." -ForegroundColor Yellow
        $fileName = (Get-Item $SourceFile).Name

        #Creating Intune app body JSON data to pass to the service
        $body = Get-iOSAppBody $displayName $publisher $description $fileName
        Write-Output $body

        # Create the Intune application object in the service
        Write-Host "Creating application in Intune..." -ForegroundColor Yellow
        $mobileApp = New-MgDeviceAppManagementMobileApp -BodyParameter $body

        # Get the content version for the new app (this will always be 1 until the new app is committed).
        Write-Host "Creating Content Version in the service for the application..." -ForegroundColor Yellow
        $appId = $mobileApp.id;
        $contentVersionUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions";
        $contentVersion = Invoke-MgGraphRequest -Method POST -Uri $contentVersionUri "{}" ;

        # Encrypt file and Get File Information
        Write-Host "Encrypting the file '$SourceFile'..." -ForegroundColor Yellow
        $encryptionInfo = EncryptFile $sourceFile $tempFile;
        $Size = (Get-Item "$sourceFile").Length
        $EncrySize = (Get-Item "$tempFile").Length

        Write-Host "Creating the manifest file used to install the application on the device..." -ForegroundColor Yellow
        [string]$manifestXML = '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>items</key><array><dict><key>assets</key><array><dict><key>kind</key><string>software-package</string><key>url</key><string>{UrlPlaceHolder}</string></dict></array><key>metadata</key><dict><key>AppRestrictionPolicyTemplate</key> <string>http://management.microsoft.com/PolicyTemplates/AppRestrictions/iOS/v1</string><key>AppRestrictionTechnology</key><string>Windows Intune Application Restrictions Technology for iOS</string><key>IntuneMAMVersion</key><string></string><key>CFBundleSupportedPlatforms</key><array><string>iPhoneOS</string></array><key>MinimumOSVersion</key><string>9.0</string><key>bundle-identifier</key><string>bundleid</string><key>bundle-version</key><string>bundleversion</string><key>kind</key><string>software</string><key>subtitle</key><string>LaunchMeSubtitle</string><key>title</key><string>bundletitle</string></dict></dict></array></dict></plist>'
        $manifestXML = $manifestXML.replace("bundleid", "$bundleId")
        $manifestXML = $manifestXML.replace("bundleversion", "$versionNumber")
        $manifestXML = $manifestXML.replace("bundletitle", "$displayName")

        $Bytes = [System.Text.Encoding]::ASCII.GetBytes($manifestXML)
        $EncodedText = [Convert]::ToBase64String($Bytes)

        # Create a new file for the app.
        Write-Host "Creating a new file entry in Azure for the upload..." -ForegroundColor Yellow
        $contentVersionId = $contentVersion.id;
        $fileBody = GetAppFileBody "$filename" $Size $EncrySize "$EncodedText";
        $filesUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files";
        $file = Invoke-MgGraphRequest -Method POST -Uri $filesUri ($fileBody | ConvertTo-Json);

        # Wait for the service to process the new file request.
        Write-Host "Waiting for the file entry URI to be created..." -ForegroundColor Yellow
        $fileId = $file.id;
        $fileUri = "$baseUrl/mobileapps/$appId/$LOBType/contentVersions/$contentVersionId/files/$fileId";
        $file = WaitForFileProcessing $fileUri "AzureStorageUriRequest";

        # Upload the content to Azure Storage.
        Write-Host "Uploading file to Azure Storage..." -f Yellow
        UploadFileToAzureStorage $file.azureStorageUri $tempFile $BlockSizeMB

        # Commit the file.
        Write-Host "Committing the file into Azure Storage..." -ForegroundColor Yellow
        $commitFileUri = "$baseUrl/mobileApps/$appId/$LOBType/contentVersions/$contentVersionId/files/$fileId/commit";
        Invoke-MgGraphRequest -Method POST $commitFileUri -Body ($encryptionInfo | ConvertTo-Json);

        # Wait for the service to process the commit file request.
        Write-Host "Waiting for the service to process the commit file request..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "CommitFile";

        # Commit the app.
        Write-Host "Committing the app body..." -ForegroundColor Yellow
        $commitAppBody = GetAppCommitBody $contentVersionId $LOBType;
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
        Write-Error "Aborting with exception: $($_.Exception.ToString())";
	throw $_
    }
    finally {
        # Cleaning up temporary files and directories
        Remove-Item -Path "$tempFile" -Force -ErrorAction SilentlyContinue
        Remove-Item -Path "$ExtractedPath" -Force -ErrorAction SilentlyContinue
    }
}

## Example
#Invoke-iOSLobAppUpload -SourceFile "C:\IntuneApps\MyLobApp.ipa" -displayName "A test application to deploy via Intune" -Publisher "Contoso" -Description "A test application to deploy via Intune."
