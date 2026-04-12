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
# GOOGLE / AOSP
# ==========================================================

"SpeechServicesByGoogle" "LiveTranscribe" "DigitalWellbeing" "Maps" "Duo"
"Photos" "AssistantShell" "BardShell" "DuoStub"
"GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "GoogleRestore"
"SearchSelector" "VoiceAccess"

"Videos" "Music2"
"ChromeCustomizations" "Velvet" "LocationHistory" "LocationSharing"
"YouTube" "YouTubeMusicPrebuilt" "PrebuiltGemini"

# ==========================================================
# GOOGLE CORE APPS (FULL REMOVAL)
# ==========================================================

"Gmail" "Gmail2" "PrebuiltGmail" "GoogleMail"
"Drive" "Drive_Android" "GoogleDrive"
"Chrome" "ChromePublic" "GoogleChrome"

# ==========================================================
# SAMSUNG CORE
# ==========================================================

"SamsungCalendar" "Notes40" "SamsungMembers" "Tips" "VoiceNote_5.0"

# ==========================================================
# SAMSUNG MESSAGES STACK (FULL REMOVAL)
# ==========================================================

"SamsungMessages" "SecMms" "MmsService"
"MessageApp" "Messages" "Messaging_10.1"
"RcsService" "SamsungMessagesRcs"

# ==========================================================
# ECOSYSTEM / SMART FEATURES (FULL STRIP)
# ==========================================================

"MdecService" "LinkToWindowsService"
"SmartSwitchStub" "OneDrive_Samsung_v3"

# SmartThings FULL REMOVAL
"SmartThingsKit" "SmartThingsFramework" "SmartThingsService"
"SmartThingsAgent" "SmartThingsHub"
"SmartThingsHome" "SmartThingsEdge"
"SmartThingsWifi" "SmartThingsDeviceSDK"
"SmartThings" "SmartThingsCore"

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
# SYSTEM APPS / MEDIA / SERVICES
# ==========================================================

"LiveDrawing" "PhotoTable" "VideoEditorLite_Dream_N"
"GalleryWidget" "KidsHome_Installer" "ParentalCare"
"SmartReminder" "SmartPush" "SmartPush_64"
"MinusOnePage" "MoccaMobile" "VisionIntelligence3.7"
"VTCameraSetting" "HashTagService" "LedCoverService"
"MemorySaver_O_Refresh" "OMCAgent5" "StoryService"
"SumeNNService" "SolarAudio-service"
"SPPPushClient" "sticker" "Fast" "FunModeSDK"

"SVoiceIME" "SamsungTTS"

# ==========================================================
# CONNECTIVITY / SHARING (FULL STRIP)
# ==========================================================

"LinkSharing_v11"

# Quick Share / Nearby
"QuickShare" "NearbyShare" "ShareLiveService"

# Music Share
"MusicShare" "MusicShareApp" "MusicShareService"

# Auto Switch Buds
"AutoSwitchBuds" "AutoSwitchBudsService"

# Smart View / Mirroring
"SmartView" "ScreenMirroring" "MirroringService"
"SmartViewSDK" "SmartViewReceiver"

# ==========================================================
# MULTI DEVICE
# ==========================================================

"MultiControl" "MultiConnectivity"
"DeviceContinuity" "SamsungMultiConnectivity"
"ContinueOnOtherDevices" "SamsungContinuityService"

# ==========================================================
# OTA / UPDATE SYSTEM (FULL KILL)
# ==========================================================

"FotaAgent" "FotaService" "FotaClient"
"SoftwareUpdate" "SoftwareUpdateUI"
"SystemUpdate" "Updater" "UpdateService"
"SDMService" "RemoteUpdateService"
"UpdateEngine" "UpdateEngineService"
"RecoverySystem"
"KnoxUpdateAgent" "DevicePolicyUpdate" "MDMUpdateService"

# ==========================================================
# CARRIER BLOAT
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
# SYSTEM CORE
# ==========================================================

"BluetoothMidiService" "PrintSpooler" "WebManual"
"WifiGuider" "UltraDataSaving_O" "Upday"

# ==========================================================
# PRELOAD / FACEBOOK / NETFLIX
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
"DigitalKey" "EarphoneTypeC"
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
# USER REMOVED / BLOAT
# ==========================================================

"AppCloud" "SamsungStore" "MyGalaxy"

# ==========================================================
# INTELLIGENCE / UI LAYER REMOVAL
# ==========================================================

"SamsungDeX" "DexSystemUI" "DesktopMode" "DesktopModeUI"
"SamsungFree"

"OneUIHome_Routines" "BixbyRoutines"

"ADPersonalizationService" "SamsungAds" "MarketingService" "CustomService"

"EdgePanels" "TaskEdge" "OneHandOperationPlus"

"SmartCapture" "ScreenshotService"

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
    echo -e "- Removing apps..."

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
# SYSTEM EXT CLEANUP
###################################################################################################

REMOVE_SYSTEM_EXT() {
    local DIR="$1"
    echo "- Cleaning system_ext..."

    rm -rf "$DIR/system_ext/app"
    rm -rf "$DIR/system_ext/priv-app"
    rm -rf "$DIR/system_ext/etc/permissions"
    rm -rf "$DIR/system_ext/etc/sysconfig"
}

###################################################################################################
# OVERLAYS REMOVAL
###################################################################################################

REMOVE_OVERLAYS() {
    local DIR="$1"
    echo "- Removing overlays..."

    rm -rf "$DIR/product/overlay"
    rm -rf "$DIR/system/system/product/overlay"
    rm -rf "$DIR/system/system/system_ext/overlay"
    rm -rf "$DIR/system_ext/overlay"
}

###################################################################################################
# ESIM REMOVAL
###################################################################################################

REMOVE_ESIM_FILES() {
    local DIR="$1"
    echo "- Removing ESIM..."

    rm -rf "$DIR/system/system/priv-app/EsimClient"
    rm -rf "$DIR/system/system/priv-app/EuiccService"
}

###################################################################################################
# FABRIC CRYPTO REMOVAL
###################################################################################################

REMOVE_FABRIC_CRYPTO() {
    local DIR="$1"
    echo "- Removing Fabric Crypto..."

    rm -rf "$DIR/system/system/bin/fabric_crypto"
    rm -rf "$DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$DIR/system/system/priv-app/KmxService"
}

###################################################################################################
# OTA REMOVAL
###################################################################################################

REMOVE_OTA_INFRASTRUCTURE() {
    local DIR="$1"
    echo "- Removing OTA..."

    rm -rf "$DIR/system/system/priv-app/FotaAgent"
    rm -rf "$DIR/system/system/priv-app/FotaService"
    rm -rf "$DIR/system/system/priv-app/SDMService"
}

###################################################################################################
# SYSTEM FEATURE STRIP
###################################################################################################

REMOVE_SYSTEM_FEATURES() {
    local DIR="$1"
    echo "- Removing system features..."

    rm -rf "$DIR/system/system/etc/permissions/*"
    rm -rf "$DIR/system/system/etc/sysconfig/*"
}

###################################################################################################
# CLEAN RESIDUAL FILES
###################################################################################################

CLEAN_RESIDUAL_FILES() {
    local DIR="$1"
    echo "- Cleaning residuals..."

    find "$DIR" -type d -name "oat" -exec rm -rf {} +
    rm -rf "$DIR/system/system/log"
    rm -rf "$DIR/system/system/preload"
    rm -rf "$DIR/system/system/hidden"
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

    echo -e "${YELLOW}Starting EXTREME ROM Debloat...${NC}"

    KICK "$DIR"
    REMOVE_ESIM_FILES "$DIR"
    REMOVE_FABRIC_CRYPTO "$DIR"
    REMOVE_SYSTEM_FEATURES "$DIR"
    REMOVE_OTA_INFRASTRUCTURE "$DIR"
    REMOVE_OVERLAYS "$DIR"
    REMOVE_SYSTEM_EXT "$DIR"
    CLEAN_RESIDUAL_FILES "$DIR"
    OPTIMIZE_BUILD_PROP "$DIR"

    echo -e "${YELLOW}DONE: EXTREME DEBLOAT COMPLETE${NC}"
}
