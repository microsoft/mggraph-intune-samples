Import-Module Microsoft.Graph.Beta.DeviceManagement.Enrollment
Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions

<# region Authentication
To authenticate, you'll use the Microsoft Graph PowerShell SDK. If you haven't already installed the SDK, see this guide:
https://learn.microsoft.com/en-us/powershell/microsoftgraph/installation?view=graph-powershell-1.0 
The PowerShell SDK supports two types of authentication: delegated access, and app-only access. 
For details on using delegated access, see this guide here:
https://learn.microsoft.com/powershell/microsoftgraph/get-started?view=graph-powershell-1.0
For details on using app-only access for unattended scenarios, see Use app-only authentication with the Microsoft Graph PowerShell SDK:
https://learn.microsoft.com/powershell/microsoftgraph/app-only?view=graph-powershell-1.0&tabs=azure-portal 
#>

# Get and display all AOSP enrollment profiles
$EnrollmentProfiles = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -Filter "enrollmentMode eq 'corporateOwnedAOSPUserAssociatedDevice' or enrollmentMode eq 'corporateOwnedAOSPUserlessDevice'" -Property "Id, displayName, enrollmentMode, tokenValue, tokenCreationDateTime,tokenExpirationDateTime, qrCodeContent" 
$EnrollmentProfiles | Select-Object -Property "Id", "displayName", "EnrollmentMode", "tokenCreationDateTime", "tokenExpirationDateTime" | Format-Table -AutoSize

# If there are no AOSP enrollment profiles, exit
if ($EnrollmentProfiles.Count -eq 0) {
    Write-Output "No AOSP enrollment profiles found. Exiting..."
    return
}

####################################################    
# Function that is used to renew AOSP enrollment tokens
function Invoke-AOSPEnrollmentTokenRenewal() {
    [CmdletBinding()]
    param(
        [switch]$All,
        [string]$AndroidDeviceOwnerEnrollmentProfileId,
        [int]$TokenValidityInSeconds
    )
    # Constuct the request body containing the token validity period in seconds
    ## If token validity is set, use the specified value
    if ($TokenValidityInSeconds) {
        $body = @{
            tokenValidityInSeconds = $TokenValidityInSeconds
        }    
    }
    #If token validity is not set, use default value
    elseif (!$TokenValidityInSeconds) {
        $body = @{
            #7776000 seconds = 90 days (maximum AOSP token validity)
            tokenValidityInSeconds = 7776000
        }    
    }

    # If both -All and -AndroidDeviceOwnerEnrollmentProfileId parameters are used, throw an error
    if ($All -and $AndroidDeviceOwnerEnrollmentProfileId) {
        throw "'-All' and '-AndroidDeviceOwnerEnrollmentProfileId' parameters can't be used at the same time."
    }

    # If -All parameter is used, renew all AOSP enrollment tokens
    if ($All) {
        foreach ($TokenId in $EnrollmentProfiles.Id) {          
            #Renew token, using the token ID and the body parameter containing the new token validity period in seconds 
            New-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfileToken -AndroidDeviceOwnerEnrollmentProfileId ('AOSP-' + $TokenId) -BodyParameter $body
            if ($?) {
                Write-Output "Successfully renewed token for enrollment profile $TokenId"
            }
            else {
                Write-Error "Failed to renew token for enrollment profile $TokenId"
            }
        }
    }

    # If -AndroidDeviceOwnerEnrollmentProfileId parameter is used, renew the AOSP enrollment token with the specified ID
    if ($AndroidDeviceOwnerEnrollmentProfileId) {
        #Renew token, using the token ID and the body parameter containing the new token validity period in seconds 
        New-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfileToken -AndroidDeviceOwnerEnrollmentProfileId ('AOSP-' + $AndroidDeviceOwnerEnrollmentProfileId) -BodyParameter $body
        if ($?) {
            Write-Output "Successfully renewed token for enrollment profile $AndroidDeviceOwnerEnrollmentProfileId"
        }
        else {
            Write-Error "Failed to renew token for enrollment profile $AndroidDeviceOwnerEnrollmentProfileId"
        }
    }
}

####################################################
# Function that is used to export AOSP enrollment tokens, matching the same JSON schema as the Intune console's export
function Export-AOSPEnrollmentTokenJSON() {
    [CmdletBinding()]
    param(
        [switch]$All,
        [string]$AndroidDeviceOwnerEnrollmentProfileId,
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    # If both -All and -AndroidDeviceOwnerEnrollmentProfileId parameters are used, throw an error
    if ($All -and $AndroidDeviceOwnerEnrollmentProfileId) {
        throw "'-All' and '-AndroidDeviceOwnerEnrollmentProfileId' parameters can't be used at the same time."
    }

    # If -AndroidDeviceOwnerEnrollmentProfileId parameter is used, export the AOSP enrollment token JSON with the specified ID
    if ($AndroidDeviceOwnerEnrollmentProfileId) {
        # Get AOSP enrollment token data
        $TokenData = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -AndroidDeviceOwnerEnrollmentProfileId $AndroidDeviceOwnerEnrollmentProfileId -Property "tokenValue,tokenCreationDateTime,tokenExpirationDateTime,qrCodeContent" 
        $TokenData = $TokenData | Select-Object -Property "qrCodeContent", "tokenExpirationDateTime" 

        #Decode $TokenData.QRContent from base64 and convert to JSON
        $TokenData.QrCodeContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($TokenData.QrCodeContent))
        $TokenData.QrCodeContent = $TokenData.QrCodeContent | ConvertFrom-Json

        #Construct JSON object
        $JSON = New-Object -TypeName PSObject

        #rename QrCodeContent to qrCodeContent
        $JSON | Add-Member -MemberType NoteProperty -Name "qrCodeContent" -Value $TokenData.QrCodeContent -Force
        #rename TokenExpirationDateTime to tokenExpirationDateTime
        $JSON | Add-Member -MemberType NoteProperty -Name "expirationDate" -Value $TokenData.TokenExpirationDateTime -Force

        #Convert $TokenData from PSObject to JSON
        $JSON = $JSON | ConvertTo-Json -Depth 100
    
        # Creating JSON file
        $filename = "$ExportPath\$AndroidDeviceOwnerEnrollmentProfileId.json"

        # Write JSON to file
        $JSON | Out-File $filename -Force

        # Check if file was created
        if (Test-Path $filename) {
            Write-Host "Success: " -NoNewline -ForegroundColor Green
            Write-Host "JSON code exported to " -NoNewline
            Write-Host "$filename" -ForegroundColor Yellow

        }
        else {
            Write-Host "Unable to create file." -ForegroundColor Red
        }
    }

    # If -All parameter is used, export all AOSP enrollment token JSONs
    elseif ($All) {
        # Loop through all AOSP enrollment profiles
        foreach ($TokenId in $EnrollmentProfiles.Id) {
            # Get AOSP enrollment token data
            $TokenData = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -AndroidDeviceOwnerEnrollmentProfileId $TokenId -Property "tokenValue,tokenCreationDateTime,tokenExpirationDateTime,qrCodeContent" 
            $TokenData = $TokenData | Select-Object -Property "qrCodeContent", "tokenExpirationDateTime" 
        
            #Decode $TokenData.QRContent from base64 and convert to JSON
            $TokenData.QrCodeContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($TokenData.QrCodeContent))
            $TokenData.QrCodeContent = $TokenData.QrCodeContent | ConvertFrom-Json
        
            #Construct JSON object
            $JSON = New-Object -TypeName PSObject
        
            #rename QrCodeContent to qrCodeContent
            $JSON | Add-Member -MemberType NoteProperty -Name "qrCodeContent" -Value $TokenData.QrCodeContent -Force
            #rename TokenExpirationDateTime to tokenExpirationDateTime
            $JSON | Add-Member -MemberType NoteProperty -Name "expirationDate" -Value $TokenData.TokenExpirationDateTime -Force
        
            #Convert $TokenData from PSObject to JSON
            $JSON = $JSON | ConvertTo-Json -Depth 100
            
            # Creating file
            $filename = "$ExportPath\$TokenId.json"
        
            # Write JSON to file
            $JSON | Out-File $filename
        
            # Check if file was created
            if (Test-Path $filename) {
                Write-Host "Success: " -NoNewline -ForegroundColor Green
                Write-Host "JSON exported to " -NoNewline
                Write-Host "$filename" -ForegroundColor Yellow
            }
            else {
                Write-Host "Unable to create file." -ForegroundColor Red
            }
        }
    }
}

####################################################
# Function that is used to export AOSP enrollment token information as QR codes
function Export-AOSPEnrollmentTokenQRCode() {
    [CmdletBinding()]
    param(
        [switch]$All,
        [string]$AndroidDeviceOwnerEnrollmentProfileId,
        [Parameter(Mandatory = $true)]
        [string]$ExportPath
    )

    # If both -All and -AndroidDeviceOwnerEnrollmentProfileId parameters are used, throw an error
    if ($All -and $AndroidDeviceOwnerEnrollmentProfileId) {
        throw "'-All' and '-AndroidDeviceOwnerEnrollmentProfileId' parameters can't be used at the same time."
    }

    # If -AndroidDeviceOwnerEnrollmentProfileId parameter is used, export the AOSP enrollment token QR code with the specified ID
    if ($AndroidDeviceOwnerEnrollmentProfileId) {
        # Get QR code data
        $QR = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -AndroidDeviceOwnerEnrollmentProfileId $AndroidDeviceOwnerEnrollmentProfileId -Select qrCodeImage
        $QRType = $QR.qrCodeImage.type
        $QRValue = $QR.qrCodeImage.value
    
        # Creating file and writing QR code data to file
        $imageType = $QRType.split("/")[1]
        $filename = "$ExportPath\$AndroidDeviceOwnerEnrollmentProfileId.$imageType"
        [IO.File]::WriteAllBytes($filename, $QRValue)

        # Check if file was created
        if (Test-Path $filename) {
            Write-Host "Success: " -NoNewline -ForegroundColor Green
            Write-Host "QR code exported to " -NoNewline
            Write-Host "$filename" -ForegroundColor Yellow
        }
        else {
            Write-Host "Unable to create file." -ForegroundColor Red
        }
    }

    # If -All parameter is used, export all AOSP enrollment token QR codes
    elseif ($All) {
        # Loop through all AOSP enrollment profiles
        foreach ($TokenId in $EnrollmentProfiles.Id) {
            # Get QR code data
            $QR = Get-MgBetaDeviceManagementAndroidDeviceOwnerEnrollmentProfile -AndroidDeviceOwnerEnrollmentProfileId $TokenId -Select qrCodeImage
            $QRType = $QR.qrCodeImage.type
            $QRValue = $QR.qrCodeImage.value
            
            # Creating file
            $imageType = $QRType.split("/")[1]
            $filename = "$ExportPath\$TokenId.$imageType"
            [IO.File]::WriteAllBytes($filename, $QRValue)

            # Check if file was created
            if (Test-Path $filename) {
                Write-Host "Success: " -NoNewline -ForegroundColor Green
                Write-Host "QR code exported to " -NoNewline
                Write-Host "$filename" -ForegroundColor Yellow
            }
            else {
                Write-Host "Unable to create file." -ForegroundColor Red
            }
        }
    }
}
