#!/bin/bash

###################################################################################################
# COLORS
###################################################################################################

RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

###################################################################################################
# FINAL AGGRESSIVE DEBLOAT LIST (EXTREME MODE)
###################################################################################################

DEBLOAT_APPS=(

# ==========================================================
# GOOGLE / AOSP CORE
# ==========================================================

"SpeechServicesByGoogle" "LiveTranscribe" "DigitalWellbeing"
"Maps" "Duo" "Photos" "AssistantShell" "BardShell" "DuoStub"
"GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "GoogleRestore"
"SearchSelector" "VoiceAccess"

"Videos" "Music2"
"ChromeCustomizations" "Velvet" "LocationHistory" "LocationSharing"

"PrebuiltGemini"

# --- Gmail (FULL REMOVAL) ---
"Gmail" "Gmail2" "PrebuiltGmail" "GoogleMail" "GmailProvider"

# --- Google Drive (FULL REMOVAL) ---
"Drive" "Drive_Android" "GoogleDrive" "DriveSync"

# --- Google Chrome (FULL REMOVAL) ---
"Chrome" "ChromePublic" "GoogleChrome" "ChromeCustomizations"

# --- YouTube (ADDED) ---
"YouTube" "YouTubeMusic" "PrebuiltYouTube" "YouTubeStub"

# ==========================================================
# SAMSUNG CORE
# ==========================================================

"SamsungCalendar" "Notes40" "SamsungMembers" "Tips" "VoiceNote_5.0"

# ==========================================================
# SAMSUNG ECOSYSTEM
# ==========================================================

"MdecService" "LinkToWindowsService"
"SmartSwitchStub" "OneDrive_Samsung_v3"

# ==========================================================
# KNOX
# ==========================================================

"KnoxEnrollmentService" "KnoxPushManager" "KLMSAgent"

# ==========================================================
# GAMING / VPN
# ==========================================================

"GameTools_Dream" "GameHome"
"SamsungMax" "SamsungVPN"

# ==========================================================
# CAMERA / AR
# ==========================================================

"ARCore" "ARDrawing" "ARZone" "AREmoji" "AREmojiEditor"
"AvatarEmojiSticker" "AvatarEmojiSticker_S" "StickerFaceARAvatar"
"LiveStickers"

# ==========================================================
# BIXBY
# ==========================================================

"Bixby" "BixbyWakeup" "BixbyInterpreter"
"BixbyVisionFramework3.5" "SettingsBixby"

# ==========================================================
# ANALYTICS
# ==========================================================

"DiagMonAgent" "SamsungAnalytics"
"SOAgent7" "SOAgent75" "SOAgent76" "SOAgent77"

# ==========================================================
# UI / FEATURES
# ==========================================================

"EdgeLighting" "PeopleStripe" "AirGlance" "AirReadingGlass"
"SmartSuggestions" "SamsungSmartSuggestions"

# ==========================================================
# MULTIMEDIA / SYSTEM APPS
# ==========================================================

"LiveDrawing" "PhotoTable" "VideoEditorLite_Dream_N"
"GalleryWidget" "KidsHome_Installer" "ParentalCare"
"SmartReminder" "SmartPush" "SmartPush_64"
"MinusOnePage" "MoccaMobile" "VisionIntelligence3.7"
"VTCameraSetting" "HashTagService" "LedCoverService"
"MemorySaver_O_Refresh" "OMCAgent5" "StoryService"
"SumeNNService" "SolarAudio-service"
"SPPPushClient" "sticker" "Fast" "FunModeSDK"

# ==========================================================
# VOICE / AUDIO
# ==========================================================

"SVoiceIME" "SamsungTTS"

# ==========================================================
# CONNECTIVITY / SHARING (CORE)
# ==========================================================

"LinkSharing_v11"

# ==========================================================
# SAMSUNG FEATURE STACK REMOVAL
# ==========================================================

"MusicShare" "MusicShareService" "MusicShareClient"

"QuickShare" "QuickShareService" "NearbyShare" "NearbyService"

"AutoSwitchBuds" "AutoSwitchBudsService"

"SmartView" "ScreenMirroring" "MirroringService"

"SmartThingsKit" "SmartThingsFramework" "SmartThingsService"
"SmartThings" "SmartThingsAgent" "SmartThingsCore"

# ==========================================================
# MULTI DEVICE / CONTINUITY
# ==========================================================

"MultiControl" "MultiConnectivity"
"DeviceContinuity" "SamsungMultiConnectivity"
"ContinueOnOtherDevices" "SamsungContinuityService"

# ==========================================================
# ANDROID AUTO
# ==========================================================

"AndroidAuto" "AndroidAutoStub" "CarIntegrationService"

# ==========================================================
# OTA / UPDATES
# ==========================================================

"FotaAgent" "FotaService" "FotaClient"
"SoftwareUpdate" "SoftwareUpdateUI"
"SystemUpdate" "Updater" "UpdateService"
"SDMService" "RemoteUpdateService"
"UpdateEngine" "UpdateEngineService"
"RecoverySystem"
"KnoxUpdateAgent" "DevicePolicyUpdate" "MDMUpdateService"

# ==========================================================
# CARRIER APPS
# ==========================================================

"KTAuth" "KTCustomerService" "KTUsimManager"
"KTServiceAgent" "KTServiceMenu" "KT114Provider2"
"KTHiddenMenu" "KTOneStore"

"SKTMemberShip" "SKTMemberShip_new"
"SKTFindLostPhone" "SKTFindLostPhoneApp"
"SKTHiddenMenu" "SKTOneStore" "SktUsimService"

"LGUMiniCustomerCenter" "LGUplusTsmProxy"
"LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore"

"TWorld" "TService" "TPhoneOnePackage" "TPhoneSetup"

# ==========================================================
# SYSTEM COMPONENTS
# ==========================================================

"BluetoothMidiService" "PrintSpooler" "WebManual"
"WifiGuider" "UltraDataSaving_O" "Upday"

# ==========================================================
# FACEBOOK / PRELOAD
# ==========================================================

"FBAppManager_NS" "FBInstaller_NS" "FBServices"
"Netflix_stub"

# ==========================================================
# EXTRA SYSTEM APPS
# ==========================================================

"SetupIndiaServicesTnC"
"SamsungPass" "SamsungPassAutofill_v1"
"SamsungBilling" "UniversalMDMClient"
"Discover" "DiscoverSEP"
"DigitalKey"
"SamsungCarKeyFw"

# ==========================================================
# ACCESSIBILITY
# ==========================================================

"TalkbackSE" "SwiftkeyIme"

# ==========================================================
# LOW LEVEL SYSTEM
# ==========================================================

"vexfwk_service" "VexScanner" "LiveEffectService"

# ==========================================================
# USER REMOVED
# ==========================================================

"AppCloud" "SamsungStore" "MyGalaxy"

# ==========================================================
# UI / SYSTEM INTELLIGENCE LAYER REMOVAL
# ==========================================================

"SamsungDeX" "DexSystemUI" "DesktopMode" "DesktopModeUI"
"SamsungFree"

"OneUIHome_Routines" "BixbyRoutines"

"ADPersonalizationService" "SamsungAds" "MarketingService" "CustomService"

"EdgePanels" "TaskEdge" "OneHandOperationPlus"

"Finder"

"BixbyHome"

"AppPredictionService" "ContextService" "IntelligenceService"
"PersonalizationFramework" "UsagePatternsService"

)

###################################################################################################
# REMOVE APPS
###################################################################################################

KICK() {
    local DIR="$1"
    echo -e "- Removing selected apps."

    local APP_DIRS=(
        "$DIR/system/system/app"
        "$DIR/system/system/priv-app"
        "$DIR/product/app"
        "$DIR/product/priv-app"
    )

    for app in "${DEBLOAT_APPS[@]}"; do
        for base in "${APP_DIRS[@]}"; do
            target="$base/$app"
            [[ -d "$target" ]] && rm -rf "$target"
        done
    done
}

###################################################################################################
# REMOVE ESIM FILES
###################################################################################################

REMOVE_ESIM_FILES() {
    local DIR="$1"
    echo "- Removing ESIM components."

    rm -rf "$DIR/system/system/etc/autoinstalls/autoinstalls-com.google.android.euicc"
    rm -rf "$DIR/system/system/etc/default-permissions/default-permissions-com.google.android.euicc.xml"
    rm -rf "$DIR/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
    rm -rf "$DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"

    rm -rf "$DIR/system/system/priv-app/EsimClient"
    rm -rf "$DIR/system/system/priv-app/EuiccService"
}

###################################################################################################
# REMOVE FABRIC CRYPTO
###################################################################################################

REMOVE_FABRIC_CRYPTO() {
    local DIR="$1"
    echo "- Removing Fabric Crypto."

    rm -rf "$DIR/system/system/bin/fabric_crypto"
    rm -rf "$DIR/system/system/etc/init/fabric_crypto.rc"
    rm -rf "$DIR/system/system/etc/permissions/FabricCryptoLib.xml"
    rm -rf "$DIR/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    rm -rf "$DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$DIR/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    rm -rf "$DIR/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    rm -rf "$DIR/system/system/priv-app/KmxService"
}

###################################################################################################
# OTA INFRASTRUCTURE REMOVAL
###################################################################################################

REMOVE_OTA_INFRASTRUCTURE() {
    local DIR="$1"
    echo "- Removing OTA infrastructure."

    rm -rf "$DIR/system/system/etc/permissions/*update*"
    rm -rf "$DIR/system/system/etc/sysconfig/*update*"
    rm -rf "$DIR/system/system/etc/init/*update*"

    rm -rf "$DIR/system/system/bin/update_engine*"
    rm -rf "$DIR/system/system/lib*/libupdate_engine*"

    rm -rf "$DIR/system/system/priv-app/FotaAgent"
    rm -rf "$DIR/system/system/priv-app/FotaService"
    rm -rf "$DIR/system/system/priv-app/KnoxUpdateAgent"
    rm -rf "$DIR/system/system/priv-app/SDMService"
}

###################################################################################################
# SYSTEM FEATURE STRIP
###################################################################################################

REMOVE_SYSTEM_FEATURES() {
    local DIR="$1"
    echo "- Removing system feature configs."

    rm -rf "$DIR/system/system/etc/permissions/*dex*"
    rm -rf "$DIR/system/system/etc/sysconfig/*dex*"

    rm -rf "$DIR/system/system/etc/permissions/*ads*"
    rm -rf "$DIR/system/system/etc/sysconfig/*ads*"

    rm -rf "$DIR/system/system/etc/permissions/*intelligence*"
    rm -rf "$DIR/system/system/etc/sysconfig/*intelligence*"

    rm -rf "$DIR/system/system/etc/permissions/*context*"
    rm -rf "$DIR/system/system/etc/sysconfig/*context*"

    rm -rf "$DIR/system/system/etc/permissions/*edge*"
    rm -rf "$DIR/system/system/etc/sysconfig/*edge*"

    rm -rf "$DIR/system/system/etc/permissions/*finder*"
    rm -rf "$DIR/system/system/etc/sysconfig/*finder*"

    rm -rf "$DIR/system/system/etc/permissions/*free*"
    rm -rf "$DIR/system/system/etc/sysconfig/*free*"

    rm -rf "$DIR/system/system/etc/permissions/*bixby*"
    rm -rf "$DIR/system/system/etc/sysconfig/*bixby*"
}

###################################################################################################
# CLEAN RESIDUAL FILES
###################################################################################################

CLEAN_RESIDUAL_FILES() {
    local DIR="$1"
    echo "- Cleaning residual files."

    find "$DIR/product/app" -type d -name "oat" -exec rm -rf {} +
    find "$DIR/product/priv-app" -type d -name "oat" -exec rm -rf {} +

    rm -rf "$DIR/system/system/etc/sync"
    rm -rf "$DIR/system/system/log"
    rm -rf "$DIR/system/system/preload"
    rm -rf "$DIR/system/system/tts"
    rm -rf "$DIR/system/system/hidden"
    rm -rf "$DIR/system/system/etc/mediasearch"
    rm -rf "$DIR/system/system/priv-app/MediaSearch"

    rm -rf "$DIR/product/app/SpeechServicesByGoogle/oat"
    rm -rf "$DIR/product/priv-app"/HotwordEnrollment*
}

###################################################################################################
# BUILD PROP OPTIMIZATION
###################################################################################################

OPTIMIZE_BUILD_PROP() {
    local FILE="$1/system/system/build.prop"

    grep -q "persist.sys.logd.enable" "$FILE" || echo "persist.sys.logd.enable=0" >> "$FILE"
    grep -q "windowsmgr.max_events_per_sec" "$FILE" || echo "windowsmgr.max_events_per_sec=90" >> "$FILE"
}

###################################################################################################
# MAIN
###################################################################################################

DEBLOAT() {
    local DIR="$1"

    echo -e "${YELLOW}Starting Extreme Debloat...${NC}"

    KICK "$DIR"
    REMOVE_ESIM_FILES "$DIR"
    REMOVE_FABRIC_CRYPTO "$DIR"
    REMOVE_SYSTEM_FEATURES "$DIR"
    REMOVE_OTA_INFRASTRUCTURE "$DIR"
    CLEAN_RESIDUAL_FILES "$DIR"
    OPTIMIZE_BUILD_PROP "$DIR"

    echo -e "${YELLOW}Debloat Complete (Extreme Mode).${NC}"
}
