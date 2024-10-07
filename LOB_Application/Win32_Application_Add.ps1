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
# Function to upload a file to Azure Storage using the SAS URI
function UploadFileToAzureStorage($sasUri, $filepath, $blockSizeMB) {
    # Chunk size in MiB
    $chunkSizeInBytes = (1024 * 1024 * $blockSizeMB)  

    # Read the whole file and find the total chunks.
    #[byte[]]$bytes = Get-Content $filepath -Encoding byte;
    # Using ReadAllBytes method as the Get-Content used alot of memory on the machine
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
        $totalBytes += $size

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
# Function to finalize the Azure Storage upload
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
# Function to construct the JSON body for a Win32 app
function GetWin32AppBody() {
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
    
        [parameter(Mandatory = $true)]
        [ValidateSet('system', 'user')]
        [string]$RunAsAccount,

        [parameter(Mandatory = $true)]
        [ValidateSet('basedOnReturnCode', 'allow', 'suppress', 'force')]
        [string]$DeviceRestartBehavior,
    
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
    
    if ($MSI) {
        $body = @{ "@odata.type" = "#microsoft.graph.win32LobApp" }
        $body.applicableArchitectures = "x64,x86"
        $body.description = $description
        $body.developer = ""
        $body.displayName = $displayName
        $body.fileName = $filename
        $body.installCommandLine = "msiexec /i `"$SetupFileName`""
        $body.installExperience = @{
            "runAsAccount"          = "$RunAsAccount"
            "deviceRestartBehavior" = $DeviceRestartBehavior 
        }
        $body.informationUrl = $null
        $body.isFeatured = $false
        $body.minimumSupportedOperatingSystem = @{"v10_1607" = $true }
        $body.msiInformation = @{
            "packageType"    = "$MsiPackageType"
            "productCode"    = "$MsiProductCode"
            "productName"    = "$MsiProductName"
            "productVersion" = "$MsiProductVersion"
            "publisher"      = "$MsiPublisher"
            "requiresReboot" = "$MsiRequiresReboot"
            "upgradeCode"    = "$MsiUpgradeCode"
            "@odata.type"    = "#microsoft.graph.win32LobAppMsiInformation"
        }
        $body.notes = ""
        $body.owner = ""
        $body.privacyInformationUrl = $null
        $body.publisher = $publisher
        $body.runAs32bit = $false
        $body.setupFilePath = $SetupFileName
        $body.uninstallCommandLine = "msiexec /x `"$MsiProductCode`""
    }
    elseif ($EXE) {
        $body = @{ "@odata.type" = "#microsoft.graph.win32LobApp" }
        $body.description = $description
        $body.developer = ""
        $body.displayName = $displayName
        $body.fileName = $filename
        $body.installCommandLine = $installCommandLine
        $body.installExperience = @{
            "runAsAccount"          = $RunAsAccount
            "deviceRestartBehavior" = $DeviceRestartBehavior 
        }
        $body.informationUrl = $null
        $body.isFeatured = $false
        $body.minimumSupportedOperatingSystem = @{"v10_1607" = $true }
        $body.msiInformation = $null
        $body.notes = ""
        $body.owner = ""
        $body.privacyInformationUrl = $null
        $body.publisher = $publisher
        $body.runAs32bit = $false
        $body.setupFilePath = $SetupFileName
        $body.uninstallCommandLine = $uninstallCommandLine
    }

    $body
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
    
        if (!(test-path "$SourceFile")) {
            Write-Host
            Write-Host "Source File '$sourceFile' doesn't exist..." -ForegroundColor Red
            throw
        }
    }
    
    catch {
        Write-Host -ForegroundColor Red $_.Exception.Message
        Write-Host
        break
    }
}
    
<#
.SYNOPSIS
Creates a new file system rule.

.DESCRIPTION
This function creates a new file system rule that you can use to specify a detection or requirement for a Win32 app.

.PARAMETER ruleType
The type of rule. Valid values are 'detection' or 'requirement'.

.PARAMETER path
The path to the file or folder.

.PARAMETER fileOrFolderName
The name of the file or folder.

.PARAMETER check32BitOn64System
Specifies whether to check for 32-bit on a 64-bit system.

.PARAMETER operationType
The value type returned by the script. Valid values are 'notConfigured', 'exists', 'modifiedDate', 'createdDate', 'version', 'sizeInMB', 'doesNotExist', 'sizeInBytes', 'appVersion'.

.PARAMETER operator
The operator for the detection script output comparison. Valid values are 'notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual'.

.PARAMETER comparisonValue
The value to compare the script output to.

.EXAMPLE
# Creates a new file system rule for a Win32 app.
New-FileSystemRule -ruleType detection -path 'C:\Program Files\Microsoft VS Code' -fileOrFolderName 'code.exe' -check32BitOn64System $false -operationType exists -operator notConfigured -comparisonValue $null

#>
function New-FileSystemRule() {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet("detection", "requirement")]
        [string]$ruleType,
    
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$path,
    
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$fileOrFolderName,
    
        [parameter(Mandatory = $true)]
        [bool]$check32BitOn64System,
    
        [parameter(Mandatory = $false)]
        [ValidateSet("notConfigured", "exists", "modifiedDate", "createdDate", "version", "sizeInMB", "doesNotExist", "sizeInBytes", "appVersion")]
        [string]$operationType,

        [parameter(Mandatory = $false)]
        [ValidateSet("notConfigured", "equal", "notEqual", "greaterThan", "greaterThanOrEqual", "lessThan", "lessThanOrEqual")]
        [string]$operator = "notConfigured",

        [parameter(Mandatory = $false)]
        $comparisonValue
    )

    $Rule = @{}

    if ($null -ne $comparisonValue -and $comparisonValue -ne "") {
        $Rule.comparisonValue = $comparisonValue
    }
    else {
        $Rule.comparisonValue = $null
    }

    $Rule."@odata.type" = "#microsoft.graph.win32LobAppFileSystemRule" 
    $Rule.ruleType = $ruleType
    $Rule.path = $path
    $Rule.fileOrFolderName = $fileOrFolderName
    $Rule.check32BitOn64System = $check32BitOn64System
    $Rule.operationType = $operationType
    $Rule.operator = $operator

    return $Rule
}

<#
.SYNOPSIS
Creates a new product code rule.

.DESCRIPTION
This function creates a new product code rule that you can use to specify a detection or requirement for a Win32 app.

.PARAMETER ruleType
The type of rule. Valid values are 'detection' or 'requirement'.

.PARAMETER productCode
The product code.

.PARAMETER productVersionOperator
The operator for the detection script output comparison. Valid values are 'notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual'.

.PARAMETER productVersion
The value to compare the script output to.

.EXAMPLE
# Creates a new product code rule for a Win32 app.
New-ProductCodeRule -ruleType detection -productCode "{3248F0A8-6813-4B6F-8C3A-4B6C4F5C3A1A}" -productVersionOperator equal -productVersion "130.0"
#>
function New-ProductCodeRule {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('detection', 'requirement')]
        [string]$ruleType,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$productCode,

        [parameter(Mandatory = $true)]
        [ValidateSet('notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual')]
        [string]$productVersionOperator,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$productVersion
    )

    $Rule = @{}
    $Rule."@odata.type" = "#microsoft.graph.win32LobAppProductCodeRule"
    $Rule.productCode = $productCode
    $Rule.operator = $operator
    $Rule.comparisonValue = $comparisonValue

    return $Rule
}

<#
.SYNOPSIS
Creates a new registry rule.

.DESCRIPTION
This function creates a new registry rule that you can use to specify a detection or requirement for a Win32 app.

.PARAMETER ruleType
The type of rule. Valid values are 'detection' or 'requirement'.

.PARAMETER keyPath
The registry key path.

.PARAMETER valueName
The registry value name.

.PARAMETER operationType
The operation data type (data type returned by the script). Valid values are 'notConfigured', 'exists', 'doesNotExist', 'string', 'integer', 'float', 'version'.

.PARAMETER operator
The operator for the detection script output comparison. Valid values are 'notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual'.

.PARAMETER comparisonValue
The value to compare the script output to.

.EXAMPLE
# Creates a new registry rule for a Win32 app.
New-RegistryRule -ruleType detection -keyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\xyz" -valueName "DisplayName" -operationType string -operator equal -comparisonValue "VSCode"
#>
function New-RegistryRule {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateSet('detection', 'requirement')]
        [string]$ruleType,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$keyPath,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$valueName,

        [parameter(Mandatory = $true)]
        [ValidateSet('notConfigured', 'exists', 'doesNotExist', 'string', 'integer', 'float', 'version')]
        [string]$operationType,

        [parameter(Mandatory = $true)]
        [ValidateSet('notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual')]
        [string]$operator,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$comparisonValue
    )

    $Rule = @{}
    $Rule."@odata.type" = "#microsoft.graph.win32LobAppRegistryRule"
    $Rule.ruleType = $ruleType
    $Rule.keyPath = $keyPath
    $Rule.valueName = $valueName
    $Rule.operationType = $operationType
    $Rule.operator = $operator
    $Rule.comparisonValue = $comparisonValue

    return $Rule
}

<#
.SYNOPSIS
Creates a new script detection rule.

.DESCRIPTION
This function creates a new script detection rule that you can use to specify a detection for a Win32 app.

.PARAMETER ScriptFile
The path to the script file.

.PARAMETER EnforceSignatureCheck
Specifies whether to enforce signature check.

.PARAMETER RunAs32Bit
Specifies whether to run the script as 32-bit.

.EXAMPLE
# Creates a new script detection rule for a Win32 app.
New-ScriptDetectionRule -ScriptFile "E:\VSCodeDetection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false

.NOTES
This function only creates a script detection rule. To create a script requirement rule, use the New-ScriptRequirementRule function.
#>
function New-ScriptDetectionRule() {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptFile,

        [parameter(Mandatory = $true)]
        [bool]$EnforceSignatureCheck,

        [parameter(Mandatory = $true)]
        [bool]$RunAs32Bit

    )
    if (!(Test-Path "$ScriptFile")) {
        Write-Host "Could not find file '$ScriptFile'..." -ForegroundColor Red
        Write-Host "Script can't continue..." -ForegroundColor Red
        break
    }
        
    $ScriptContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$ScriptFile"))
        
    $Rule = @{}
    $Rule."@odata.type" = "#microsoft.graph.win32LobAppPowerShellScriptRule"
    $Rule.ruleType = "detection"
    $Rule.enforceSignatureCheck = $EnforceSignatureCheck
    $Rule.runAs32Bit = $RunAs32Bit
    $Rule.scriptContent = "$ScriptContent"
    $Rule.operationType = "notConfigured"
    $Rule.operator = "notConfigured"

    return $Rule
}

<#
.SYNOPSIS
Creates a new script requirement rule.

.DESCRIPTION
This function creates a new script requirement rule that you can use to specify a requirement for a Win32 app.

.PARAMETER ScriptFile
The path to the script file.

.PARAMETER DisplayName
The display name of the rule.

.PARAMETER EnforceSignatureCheck
Specifies whether to enforce signature check.

.PARAMETER RunAs32Bit
Specifies whether to run the script as 32-bit.

.PARAMETER RunAsAccount
The account to run the script as. Valid values are 'system' or 'user'.

.PARAMETER OperationType
The operation data type (data type returned by the script). Valid values are 'notConfigured', 'string', 'dateTime', 'integer', 'float', 'version', 'boolean'.

.PARAMETER Operator
The operator for the detection script output comparison. Valid values are 'notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual'.

.PARAMETER ComparisonValue
The value to compare the script output to.

.EXAMPLE
# Creates a new script requirement rule for a Win32 app.
New-ScriptRequirementRule -ScriptFile "E:\VSCodeRequirement.ps1" -DisplayName "VS Code Requirement" -EnforceSignatureCheck $false -RunAs32Bit $false -RunAsAccount "system" -OperationType "integer" -Operator "equal" -ComparisonValue "0"

.NOTES
This function only creates a script requirement rule. To create a script detection rule, use the New-ScriptDetectionRule function.
#>
function New-ScriptRequirementRule {
    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ScriptFile,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DisplayName,

        [parameter(Mandatory = $true)]
        [bool]$EnforceSignatureCheck,

        [parameter(Mandatory = $true)]
        [bool]$RunAs32Bit,

        #Valid values are 'system' or 'user'
        [parameter(Mandatory = $true)]
        [ValidateSet('system', 'user')]
        [string]$RunAsAccount,

        [parameter(Mandatory = $true)]
        [ValidateSet('notConfigured', 'string', 'dateTime', 'integer', 'float', 'version', 'boolean')]
        [string]$OperationType,

        [parameter(Mandatory = $true)]
        [ValidateSet('notConfigured', 'equal', 'notEqual', 'greaterThan', 'greaterThanOrEqual', 'lessThan', 'lessThanOrEqual')]
        [string]$Operator,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ComparisonValue
    )

    if (!(Test-Path "$ScriptFile")) {
        Write-Host "Could not find file '$ScriptFile'..." -ForegroundColor Red
        Write-Host "Script can't continue..." -ForegroundColor Red
        break
    }

    $ScriptContent = [System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes("$ScriptFile"))
        
    $Rule = @{}
    $Rule."@odata.type" = "#microsoft.graph.win32LobAppPowerShellScriptRule"
    $Rule.displayName = $DisplayName
    $Rule.ruleType = "requirement"
    $Rule.enforceSignatureCheck = $EnforceSignatureCheck
    $Rule.runAs32Bit = $RunAs32Bit
    $Rule.scriptContent = "$ScriptContent"
    $Rule.operationType = $OperationType
    $Rule.operator = $Operator
    $Rule.comparisonValue = $ComparisonValue
    $Rule.runAsAccount = $RunAsAccount

    return $Rule
}

####################################################
# Function to get the default return codes    
function Get-DefaultReturnCodes() {
    @{"returnCode" = 0; "type" = "success" }, `
    @{"returnCode" = 1707; "type" = "success" }, `
    @{"returnCode" = 3010; "type" = "softReboot" }, `
    @{"returnCode" = 1641; "type" = "hardReboot" }, `
    @{"returnCode" = 1618; "type" = "retry" }
    
}
 
<#
.SYNOPSIS
Creates a new return code object.

.DESCRIPTION
This function creates a new return code object that you can use to specify the return codes for a Win32 app.

.PARAMETER returnCode
The return code value.

.PARAMETER type
The type of return code. Valid values are 'success', 'softReboot', 'hardReboot

.EXAMPLE
# Creates a new return code object with a return code of 0 and a type of 'success'
New-ReturnCode -returnCode 0 -type 'success'
#>
function New-ReturnCode() {
    param
    (
        [parameter(Mandatory = $true)]
        [int]$returnCode,
        [parameter(Mandatory = $true)]
        [ValidateSet('success', 'softReboot', 'hardReboot', 'retry')]
        $type
    )

    @{"returnCode" = $returnCode; "type" = "$type" }
}

####################################################
# Function to extract the IntuneWin XML file from the .intunewin file
Function Get-IntuneWinXML() {
    param
    (
        [Parameter(Mandatory = $true)]
        $SourceFile,
    
        [Parameter(Mandatory = $true)]
        $fileName,
    
        [Parameter(Mandatory = $false)]
        [bool]$removeitem = $true
    )
    
    Test-SourceFile "$SourceFile"
    
    $Directory = [System.IO.Path]::GetDirectoryName("$SourceFile")
    
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead("$SourceFile")
    
    $zip.Entries | Where-Object { $_.Name -like "$filename" } | ForEach-Object {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$Directory\$filename", $true)
    }
    
    $zip.Dispose()
    
    [xml]$IntuneWinXML = Get-Content "$Directory\$filename"
    
    return $IntuneWinXML
    
    if ($removeitem -eq $true) { remove-item "$Directory\$filename" }
}

####################################################
# Function to extract the IntuneWin file from the .intunewin file
Function Get-IntuneWinFile() {
    param
    (
        [Parameter(Mandatory = $true)]
        $SourceFile,
    
        [Parameter(Mandatory = $true)]
        $fileName,
    
        [Parameter(Mandatory = $false)]
        [string]$Folder = "win32"
    )
    
    $Directory = [System.IO.Path]::GetDirectoryName("$SourceFile")
    
    if (!(Test-Path "$Directory\$folder")) {
        New-Item -ItemType Directory -Path "$Directory" -Name "$folder" -Force
    }
    
    Add-Type -Assembly System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead(("$SourceFile"))
    $zip.Entries | Where-Object { $_.Name -like "$filename" } | ForEach-Object {
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($_, "$Directory\$folder\$filename", $true)
    }
    
    $zip.Dispose()
    
    return "$Directory\$folder\$filename"
    
    if ($removeitem -eq $true) { remove-item "$Directory\$filename" }
}

####################################################
# Function to create a new app file body containing the file and encryption information
function GetAppFileBody($name, $size, $sizeEncrypted, $manifest) {
    $body = @{ "@odata.type" = "#microsoft.graph.mobileAppContentFile" }
    $body.name = $name
    $body.size = $size
    $body.sizeEncrypted = $sizeEncrypted
    $body.manifest = $manifest
    $body.isDependency = $false
        
    $body
}

<#
.SYNOPSIS
Uploads a Win32 app to Intune.

.DESCRIPTION
This script uploads a Win32 app to Intune. The script extracts the detection.xml file from the .intunewin file and uses the information to create the app in Intune. The script then uploads the .intunewin file to Azure Storage and commits the file to the service.

.PARAMETER SourceFile
The path to the .intunewin file.

.PARAMETER displayName
The display name of the app. If not specified, the script uses the Name from the detection.xml file.

.PARAMETER publisher
The publisher of the app.

.PARAMETER description
The description of the app.

.PARAMETER Rules
An array of rules to apply to the app. You can use the New-FileSystemRule, New-ProductCodeRule, New-RegistryRule, New-ScriptDetectionRule, and New-ScriptRequirementRule functions to create the rules.

.PARAMETER returnCodes
An array of return codes to apply to the app. You can use the Get-DefaultReturnCodes and New-ReturnCode functions to create the return codes.

.PARAMETER installCommandLine
The command line to install the app. Required for EXE files.

.PARAMETER uninstallCommandLine
The command line to uninstall the app. Required for EXE files.

.PARAMETER RunAsAccount
The account to run the app as. Valid values are 'system' or 'user'.

.PARAMETER DeviceRestartBehavior
The device restart behavior for the app. Valid values are 'basedOnReturnCode', 'allow', 'suppress', 'force'.

.EXAMPLE
# Uploads a .exe Win32 app to Intune using the default return codes and a file system rule.
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-FileSystemRule -ruleType detection -check32BitOn64System $false -operationType exists -operator notConfigured -comparisonValue $null -fileOrFolderName "code.exe" -path 'C:\Program Files\Microsoft VS Code'
Invoke-Win32AppUpload -SourceFile "C:\IntuneApps\vscode\VSCodeSetup-x64-1.93.1.intunewin" -displayName "VS Code" -publisher "Microsoft" -description "VS Code" -Rules $Rules -returnCodes $returnCodes -installCommandLine "VSCodeSetup-x64-1.93.1.exe /VERYSILENT /MERGETASKS=!runcode" -uninstallCommandLine "C:\Program Files\Microsoft VS Code\unins000.exe /VERYSILENT" -DeviceRestartBehavior "basedOnReturnCode" -RunAsAccount "system" 

.EXAMPLE
# Uploads a .msi Win32 app to Intune using the default return codes and a product code rule.
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-FileSystemRule -ruleType detection -operator notConfigured -check32BitOn64System $false -operationType exists -comparisonValue $null -fileOrFolderName "firefox.exe" -path 'C:\Program Files\Mozilla Firefox\firefox.exe'
$Rules += New-ProductCodeRule detection -productCode "{3248F0A8-6813-4B6F-8C3A-4B6C4F5C3A1A}" -productVersionOperator equal -productVersion "130.0"
Invoke-Win32AppUpload -SourceFile "E:\LabScriptsAndApps\Firefox\Firefox_Setup_130.0.intunewin" -displayName "Firefox" -publisher "Mozilla" -returnCodes $returnCodes -description "Firefox browser" -Rules $Rules -RunAsAccount "system" -DeviceRestartBehavior "suppress" 

.EXAMPLE
# Uploads a Win32 app to Intune using the default return codes, a script detection rule, a script requirement rule, and a registry rule, and a registry rule.
$returnCodes = Get-DefaultReturnCodes
$Rules = @()
$Rules += New-ScriptRequirementRule -ScriptFile "E:\VSCodeRequirement.ps1" -DisplayName "VS Code Requirement" -EnforceSignatureCheck $false -RunAs32Bit $false -RunAsAccount "system" -OperationType "integer" -Operator "equal" -ComparisonValue "0"
$Rules += New-ScriptDetectionRule -ScriptFile "E:\VSCodeDetection.ps1" -EnforceSignatureCheck $false -RunAs32Bit $false 
$Rules += New-RegistryRule -ruleType detection -keyPath "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\xyz" -valueName "DisplayName" -operationType string -operator equal -comparisonValue "VSCode"
Invoke-Win32AppUpload -displayName "VS Code" -SourceFile "C:\IntuneApps\vscode\VSCodeSetup-x64-1.93.1.intunewin" -publisher "Microsoft" -description "VS Code (script detection)" -RunAsAccount "system" -Rules $Rules -returnCodes $returnCodes -InstallCommandLine "VSCodeSetup-x64-1.93.1.exe /VERYSILENT /MERGETASKS=!runcode" -UninstallCommandLine "C:\Program Files\Microsoft VS Code\unins000.exe /VERYSILENT" -DeviceRestartBehavior "basedOnReturnCode"
#>
function Invoke-Win32AppUpload {
    [cmdletbinding()]
    param
    (
        [parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceFile,

        [parameter(Mandatory = $false, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$displayName,

        [parameter(Mandatory = $true, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$publisher,

        [parameter(Mandatory = $true, Position = 4)]
        [ValidateNotNullOrEmpty()]
        [string]$description,

        [parameter(Mandatory = $true, Position = 6)]
        [ValidateNotNullOrEmpty()]
        $Rules,

        [parameter(Mandatory = $true, Position = 7)]
        [ValidateNotNullOrEmpty()]
        $returnCodes,

        [parameter(Mandatory = $false, Position = 8)]
        [string]$installCommandLine,

        [parameter(Mandatory = $false, Position = 9)]
        [string]$uninstallCommandLine,

        [parameter(Mandatory = $false, Position = 10)]
        [ValidateSet('system', 'user')]
        [string]$RunAsAccount,

        [parameter(Mandatory = $true, Position = 11)]
        [ValidateSet('basedOnReturnCode', 'allow', 'suppress', 'force')]
        [string]$DeviceRestartBehavior
    )
    try	{

        # Check if the source file exists
        Write-Host "Testing if SourceFile '$SourceFile' Path is valid..." -ForegroundColor Yellow
        Test-SourceFile "$SourceFile"

        Write-Host "Creating JSON data to pass to the service..." -ForegroundColor Yellow

        # Extract the detection.xml file from the .intunewin file
        $DetectionXML = Get-IntuneWinXML "$SourceFile" -fileName "detection.xml" -removeitem $true

        # If displayName input don't use Name from detection.xml file
        if ($displayName) { $DisplayName = $displayName }
        else { $DisplayName = $DetectionXML.ApplicationInfo.Name }
         
        $FileName = $DetectionXML.ApplicationInfo.FileName
 
        $SetupFileName = $DetectionXML.ApplicationInfo.SetupFile
 
        # Check if the file is an MSI or EXE
        $Ext = [System.IO.Path]::GetExtension($SetupFileName)

        if ((($Ext).contains("msi") -or ($Ext).contains("Msi")) -and (!$installCommandLine -or !$uninstallCommandLine)) {
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
 
            $mobileAppBody = GetWin32AppBody `
                -MSI `
                -displayName "$DisplayName" `
                -publisher "$publisher" `
                -description $description `
                -filename $FileName `
                -SetupFileName "$SetupFileName" `
                -RunAsAccount "$RunAsAccount" `
                -MsiPackageType $MsiPackageType `
                -MsiProductCode $MsiProductCode `
                -MsiProductName $displayName `
                -MsiProductVersion $MsiProductVersion `
                -MsiPublisher $MsiPublisher `
                -MsiRequiresReboot $MsiRequiresReboot `
                -MsiUpgradeCode $MsiUpgradeCode `
                -DeviceRestartBehavior "$DeviceRestartBehavior"
        }
        else {
            $mobileAppBody = GetWin32AppBody `
                -EXE -displayName "$DisplayName" `
                -publisher "$publisher" `
                -description $description `
                -filename $FileName `
                -SetupFileName "$SetupFileName" `
                -RunAsAccount $RunAsAccount `
                -DeviceRestartBehavior "$DeviceRestartBehavior" `
                -installCommandLine $installCommandLine `
                -uninstallCommandLine $uninstallCommandLine
        }

        # Add the rules and return codes to the JSON body
        if ($Rules) {
            $mobileAppBody.Add("rules", @($Rules))
        }
 
        if ($returnCodes) {
            $mobileAppBody.Add("returnCodes", @($returnCodes))
        }
        else {
            Write-Warning "Intunewin file requires ReturnCodes to be specified"
            Write-Warning "If you want to use the default ReturnCode run 'Get-DefaultReturnCodes'"
            break
        }

        # Create the application in Intune and get the application ID
        Write-Host "Creating application in Intune..." -ForegroundColor Yellow
        $MobileApp = New-MgDeviceAppManagementMobileApp -BodyParameter ($mobileAppBody | ConvertTo-Json)
        $mobileAppId = $MobileApp.id

        # Create a new content version for the application
        Write-Host "Creating Content Version in the service for the application..." -ForegroundColor Yellow
        $ContentVersion = New-MgDeviceAppManagementMobileAppAsWin32LobAppContentVersion -MobileAppId $mobileAppId -BodyParameter @{}

        # Extract the encryption information from the .intunewin file
        Write-Host "Retrieving encryption information from .intunewin file." -ForegroundColor Yellow
        $encryptionInfo = @{}
        $encryptionInfo.encryptionKey = $DetectionXML.ApplicationInfo.EncryptionInfo.EncryptionKey
        $encryptionInfo.macKey = $DetectionXML.ApplicationInfo.EncryptionInfo.macKey
        $encryptionInfo.initializationVector = $DetectionXML.ApplicationInfo.EncryptionInfo.initializationVector
        $encryptionInfo.mac = $DetectionXML.ApplicationInfo.EncryptionInfo.mac
        $encryptionInfo.profileIdentifier = "ProfileVersion1"
        $encryptionInfo.fileDigest = $DetectionXML.ApplicationInfo.EncryptionInfo.fileDigest
        $encryptionInfo.fileDigestAlgorithm = $DetectionXML.ApplicationInfo.EncryptionInfo.fileDigestAlgorithm

        $fileEncryptionInfo = @{}
        $fileEncryptionInfo.fileEncryptionInfo = $encryptionInfo

        # Extracting encrypted file
        $IntuneWinFile = Get-IntuneWinFile "$SourceFile" -fileName "$FileName"
        [int64]$Size = $DetectionXML.ApplicationInfo.UnencryptedContentSize
        $EncrySize = (Get-Item "$IntuneWinFile").Length

        # Create a new file entry in Azure for the upload
        $ContentVersionId = $ContentVersion.Id
        $fileBody = GetAppFileBody "$FileName" $Size $EncrySize $null
        $fileBody = $fileBody | ConvertTo-Json 

        # Create a new file entry in Azure for the upload and get the file ID
        Write-Host "Creating a new file entry in Azure for the upload..." -ForegroundColor Yellow
        $ContentVersionFile = New-MgDeviceAppManagementMobileAppAsWin32LobAppContentVersionFile -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -BodyParameter $fileBody
        $ContentVersionFileId = $ContentVersionFile.id
        
        # Get the file URI for the upload
        $fileUri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$mobileAppId/microsoft.graph.win32LobApp/contentVersions/$contentVersionId/files/$contentVersionFileId"

        # Upload the file to Azure Storage
        Write-Host "Uploading the file to Azure Storage..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "AzureStorageUriRequest"
        [UInt32]$BlockSizeMB = 1
        UploadFileToAzureStorage $file.azureStorageUri $IntuneWinFile $BlockSizeMB

        # Commit the file to the service
        $params = $fileEncryptionInfo | ConvertTo-Json
        Write-Host "Committing the file to the service..." -ForegroundColor Yellow
        #Wait 5 seconds before committing the file
        Start-Sleep -Seconds 5

        # Commit the file to the service
        Invoke-MgCommitDeviceAppManagementMobileAppMicrosoftGraphWin32LobAppContentVersionFile -MobileAppId $mobileAppId -MobileAppContentId $ContentVersionId -MobileAppContentFileId $ContentVersionFileId -BodyParameter $params

        # Wait for the file to be processed
        Write-Host "Waiting for the file to be processed..." -ForegroundColor Yellow
        $file = WaitForFileProcessing $fileUri "CommitFile"

        $params = @{
            "@odata.type"           = "#microsoft.graph.win32LobApp"
            committedContentVersion = "1"
        }

        $params = $params | ConvertTo-Json

        # Update the application with the new content version
        Write-Host "Updating the application with the new content version..." -ForegroundColor Yellow
        Update-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId -BodyParameter $params

        # Return the application ID
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
            Write-Host "Removing the incokplete application record from Intune..." -ForegroundColor Yellow
            Remove-MgDeviceAppManagementMobileApp -MobileAppId $mobileAppId
        }
        #>
        break
    }
}
