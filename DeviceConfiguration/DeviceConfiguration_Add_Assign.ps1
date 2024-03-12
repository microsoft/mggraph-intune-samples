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

$iOS = @"

{
    "@odata.type": "#microsoft.graph.iosGeneralDeviceConfiguration",
    "description": "",
    "displayName": "iOS Device Restriction Policy",
    "accountBlockModification": false,
    "activationLockAllowWhenSupervised": false,
    "airDropBlocked": false,
    "airDropForceUnmanagedDropTarget": false,
    "airPlayForcePairingPasswordForOutgoingRequests": false,
    "appleWatchBlockPairing": false,
    "appleWatchForceWristDetection": false,
    "appleNewsBlocked": false,
    "appsSingleAppModeBundleIds": [],
    "appsVisibilityList": [],
    "appsVisibilityListType": "none",
    "appStoreBlockAutomaticDownloads": false,
    "appStoreBlocked": false,
    "appStoreBlockInAppPurchases": false,
    "appStoreBlockUIAppInstallation": false,
    "appStoreRequirePassword": false,
    "bluetoothBlockModification": false,
    "cameraBlocked": false,
    "cellularBlockDataRoaming": false,
    "cellularBlockGlobalBackgroundFetchWhileRoaming": false,
    "cellularBlockPerAppDataModification": false,
    "cellularBlockVoiceRoaming": false,
    "certificatesBlockUntrustedTlsCertificates": false,
    "classroomAppBlockRemoteScreenObservation": false,
    "compliantAppsList": [],
    "compliantAppListType": "none",
    "configurationProfileBlockChanges": false,
    "definitionLookupBlocked": false,
    "deviceBlockEnableRestrictions": false,
    "deviceBlockEraseContentAndSettings": false,
    "deviceBlockNameModification": false,
    "diagnosticDataBlockSubmission": false,
    "diagnosticDataBlockSubmissionModification": false,
    "documentsBlockManagedDocumentsInUnmanagedApps": false,
    "documentsBlockUnmanagedDocumentsInManagedApps": false,
    "emailInDomainSuffixes": [],
    "enterpriseAppBlockTrust": false,
    "enterpriseAppBlockTrustModification": false,
    "faceTimeBlocked": false,
    "findMyFriendsBlocked": false,
    "gamingBlockGameCenterFriends": true,
    "gamingBlockMultiplayer": false,
    "gameCenterBlocked": false,
    "hostPairingBlocked": false,
    "iBooksStoreBlocked": false,
    "iBooksStoreBlockErotica": false,
    "iCloudBlockActivityContinuation": false,
    "iCloudBlockBackup": true,
    "iCloudBlockDocumentSync": true,
    "iCloudBlockManagedAppsSync": false,
    "iCloudBlockPhotoLibrary": false,
    "iCloudBlockPhotoStreamSync": true,
    "iCloudBlockSharedPhotoStream": false,
    "iCloudRequireEncryptedBackup": false,
    "iTunesBlockExplicitContent": false,
    "iTunesBlockMusicService": false,
    "iTunesBlockRadio": false,
    "keyboardBlockAutoCorrect": false,
    "keyboardBlockPredictive": false,
    "keyboardBlockShortcuts": false,
    "keyboardBlockSpellCheck": false,
    "kioskModeAllowAssistiveSpeak": false,
    "kioskModeAllowAssistiveTouchSettings": false,
    "kioskModeAllowAutoLock": false,
    "kioskModeAllowColorInversionSettings": false,
    "kioskModeAllowRingerSwitch": false,
    "kioskModeAllowScreenRotation": false,
    "kioskModeAllowSleepButton": false,
    "kioskModeAllowTouchscreen": false,
    "kioskModeAllowVoiceOverSettings": false,
    "kioskModeAllowVolumeButtons": false,
    "kioskModeAllowZoomSettings": false,
    "kioskModeAppStoreUrl": null,
    "kioskModeRequireAssistiveTouch": false,
    "kioskModeRequireColorInversion": false,
    "kioskModeRequireMonoAudio": false,
    "kioskModeRequireVoiceOver": false,
    "kioskModeRequireZoom": false,
    "kioskModeManagedAppId": null,
    "lockScreenBlockControlCenter": false,
    "lockScreenBlockNotificationView": false,
    "lockScreenBlockPassbook": false,
    "lockScreenBlockTodayView": false,
    "mediaContentRatingAustralia": null,
    "mediaContentRatingCanada": null,
    "mediaContentRatingFrance": null,
    "mediaContentRatingGermany": null,
    "mediaContentRatingIreland": null,
    "mediaContentRatingJapan": null,
    "mediaContentRatingNewZealand": null,
    "mediaContentRatingUnitedKingdom": null,
    "mediaContentRatingUnitedStates": null,
    "mediaContentRatingApps": "allAllowed",
    "messagesBlocked": false,
    "notificationsBlockSettingsModification": false,
    "passcodeBlockFingerprintUnlock": false,
    "passcodeBlockModification": false,
    "passcodeBlockSimple": true,
    "passcodeExpirationDays": null,
    "passcodeMinimumLength": 4,
    "passcodeMinutesOfInactivityBeforeLock": null,
    "passcodeMinutesOfInactivityBeforeScreenTimeout": null,
    "passcodeMinimumCharacterSetCount": null,
    "passcodePreviousPasscodeBlockCount": null,
    "passcodeSignInFailureCountBeforeWipe": null,
    "passcodeRequiredType": "deviceDefault",
    "passcodeRequired": true,
    "podcastsBlocked": false,
    "safariBlockAutofill": false,
    "safariBlockJavaScript": false,
    "safariBlockPopups": false,
    "safariBlocked": false,
    "safariCookieSettings": "browserDefault",
    "safariManagedDomains": [],
    "safariPasswordAutoFillDomains": [],
    "safariRequireFraudWarning": false,
    "screenCaptureBlocked": false,
    "siriBlocked": false,
    "siriBlockedWhenLocked": false,
    "siriBlockUserGeneratedContent": false,
    "siriRequireProfanityFilter": false,
    "spotlightBlockInternetResults": false,
    "voiceDialingBlocked": false,
    "wallpaperBlockModification": false
}

"@

####################################################

$Android = @"

{
    "@odata.type": "#microsoft.graph.androidGeneralDeviceConfiguration",
    "description": "",
    "displayName": "Android Device Restriction Policy",
    "appsBlockClipboardSharing": false,
    "appsBlockCopyPaste": false,
    "appsBlockYouTube": false,
    "bluetoothBlocked": false,
    "cameraBlocked": false,
    "cellularBlockDataRoaming": true,
    "cellularBlockMessaging": false,
    "cellularBlockVoiceRoaming": false,
    "cellularBlockWiFiTethering": false,
    "compliantAppsList": [],
    "compliantAppListType": "none",
    "diagnosticDataBlockSubmission": false,
    "locationServicesBlocked": false,
    "googleAccountBlockAutoSync": false,
    "googlePlayStoreBlocked": false,
    "kioskModeBlockSleepButton": false,
    "kioskModeBlockVolumeButtons": false,
    "kioskModeManagedAppId": null,
    "nfcBlocked": false,
    "passwordBlockFingerprintUnlock": true,
    "passwordBlockTrustAgents": false,
    "passwordExpirationDays": null,
    "passwordMinimumLength": 4,
    "passwordMinutesOfInactivityBeforeScreenTimeout": null,
    "passwordPreviousPasswordBlockCount": null,
    "passwordSignInFailureCountBeforeFactoryReset": null,
    "passwordRequiredType": "deviceDefault",
    "passwordRequired": true,
    "powerOffBlocked": false,
    "factoryResetBlocked": false,
    "screenCaptureBlocked": false,
    "deviceSharingBlocked": false,
    "storageBlockGoogleBackup": true,
    "storageBlockRemovableStorage": false,
    "storageRequireDeviceEncryption": true,
    "storageRequireRemovableStorageEncryption": true,
    "voiceAssistantBlocked": false,
    "voiceDialingBlocked": false,
    "webBrowserAllowPopups": false,
    "webBrowserBlockAutofill": false,
    "webBrowserBlockJavaScript": false,
    "webBrowserBlocked": false,
    "webBrowserCookieSettings": "browserDefault",
    "wiFiBlocked": false
}

"@

####################################################

# Setting application AAD Group to assign Policy

$AADGroup = Read-Host -Prompt "Enter the Azure AD Group ID where policies will be assigned"

$TargetGroupId = Get-MgGroup -GroupId "$AADGroup"

if ($null -eq $TargetGroupId -or $TargetGroupId -eq "") {

    Write-Host "AAD Group - '$AADGroup' doesn't exist, please specify a valid AAD Group..." -ForegroundColor Red
    Write-Host
    exit

}

# Hashtable for Target Group Assignment
$TargetGroupObject = @{
    '@odata.type' = '#microsoft.graph.groupAssignmentTarget'
    groupId       = $TargetGroupId.id
}
####################################################

Write-Host "Adding Android Device Restriction Policy from JSON..." -ForegroundColor Yellow

$CreateResult_Android = New-MgDeviceManagementDeviceConfiguration -BodyParameter $Android

Write-Host "Device Restriction Policy created as" $CreateResult_Android.id
write-host
write-host "Assigning Device Restriction Policy to AAD Group '$AADGroup'" -f Cyan

$Assign_Android = New-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $CreateResult_Android.id -Target $TargetGroupObject

Write-Host "Assigned '$AADGroup' to $($CreateResult_Android.displayName)/$($CreateResult_Android.id)"
Write-Host

####################################################

Write-Host "Adding iOS Device Restriction Policy from JSON..." -ForegroundColor Yellow
Write-Host

$CreateResult_iOS = New-MgDeviceManagementDeviceConfiguration -BodyParameter $iOS

Write-Host "Device Restriction Policy created as" $CreateResult_iOS.id
write-host
write-host "Assigning Device Restriction Policy to AAD Group '$AADGroup'" -f Cyan

$Assign_iOS = New-MgDeviceManagementDeviceConfigurationAssignment -DeviceConfigurationId $CreateResult_iOS.id -Target $TargetGroupObject

Write-Host "Assigned '$AADGroup' to $($CreateResult_iOS.displayName)/$($CreateResult_iOS.id)"
Write-Host
