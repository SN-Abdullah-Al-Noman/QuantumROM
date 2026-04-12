#!/bin/bash

###################################################################################################
# COLORS
###################################################################################################

RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

###################################################################################################
# FINAL AGGRESSIVE DEBLOAT LIST (PERFORMANCE OPTIMIZED)
###################################################################################################

DEBLOAT_APPS=(

# --- Google / AOSP ---
"SpeechServicesByGoogle" "LiveTranscribe" "DigitalWellbeing" "Maps" "Duo"
"Photos" "AssistantShell" "BardShell" "DuoStub"
"GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "GoogleRestore"
"SearchSelector" "VoiceAccess"

# --- Extra Google ---
"Drive" "GoogleOne" "BackupRestoreConfirmation" "Videos" "Music2"
"ChromeCustomizations" "Velvet" "LocationHistory" "LocationSharing"
"YouTube" "YouTubeMusicPrebuilt" "PrebuiltGemini"

# --- Samsung Core ---
"SamsungCalendar" "Notes40" "SamsungMembers" "Tips" "VoiceNote_5.0"

# --- Samsung Ecosystem ---
"MdecService" "LinkToWindowsService" "SmartThingsKit"
"SmartSwitchStub" "OneDrive_Samsung_v3"

# --- Knox ---
"KnoxEnrollmentService" "KnoxPushManager" "KLMSAgent"

# --- Gaming (GameOptimizerService REMOVED) ---
"GameTools_Dream" "GameHome"

# --- VPN / Network ---
"SamsungMax" "SamsungVPN"

# --- AR / Camera ---
"ARCore" "ARDrawing" "ARZone" "AREmoji" "AREmojiEditor"
"AvatarEmojiSticker" "AvatarEmojiSticker_S" "StickerFaceARAvatar"
"LiveStickers"

# --- Bixby ---
"Bixby" "BixbyWakeup" "BixbyInterpreter"
"BixbyVisionFramework3.5" "SettingsBixby"

# --- Analytics ---
"DiagMonAgent" "SamsungAnalytics"
"SOAgent7" "SOAgent75" "SOAgent76" "SOAgent77"

# --- UI / Features ---
"EdgeLighting" "PeopleStripe" "AirGlance" "AirReadingGlass"
"SmartSuggestions" "SamsungSmartSuggestions"

# --- Misc ---
"LiveDrawing" "PhotoTable" "VideoEditorLite_Dream_N"
"GalleryWidget" "KidsHome_Installer" "ParentalCare"
"SmartReminder" "SmartPush" "SmartPush_64"
"MinusOnePage" "MoccaMobile" "VisionIntelligence3.7"
"VTCameraSetting" "HashTagService" "LedCoverService"
"MemorySaver_O_Refresh" "OMCAgent5" "StoryService"
"SumeNNService" "SolarAudio-service"
"SPPPushClient" "sticker" "Fast" "FunModeSDK"

# --- Voice / Audio ---
"SVoiceIME" "SamsungTTS"

# --- Connectivity / Sharing ---
"LinkSharing_v11" "QuickShare"
"StorageShare" "StorageShareService"
"MusicShare"

# --- Multi Control / Continuity ---
"MultiControl" "MultiConnectivity"
"DeviceContinuity" "SamsungMultiConnectivity"

# --- Cross-device ecosystem ---
"AutoSwitchBuds"
"AutoSwitchBudsService"
"ContinueOnOtherDevices"
"SamsungContinuityService"

# --- Smart View / Mirroring ---
"SmartView"
"ScreenMirroring"
"MirroringService"

# --- Android Auto / Car ---
"AndroidAuto"
"AndroidAutoStub"
"CarIntegrationService"

# --- SmartThings ---
"SmartThingsKit"
"SmartThingsFramework"
"SmartThingsService"

###################################################################################################
# OTA / SOFTWARE UPDATE (FULL REMOVAL - NEW SECTION)
###################################################################################################

"FotaAgent"
"FotaService"
"FotaClient"
"SoftwareUpdate"
"SoftwareUpdateUI"
"SystemUpdate"
"Updater"
"UpdateService"
"SDMService"
"RemoteUpdateService"
"UpdateEngine"
"UpdateEngineService"
"RecoverySystem"
"KnoxUpdateAgent"
"DevicePolicyUpdate"
"MDMUpdateService"

# --- Carrier ---
"KTAuth" "KTCustomerService" "KTUsimManager"
"KTServiceAgent" "KTServiceMenu" "KT114Provider2"
"KTHiddenMenu" "KTOneStore"

"SKTMemberShip" "SKTMemberShip_new"
"SKTFindLostPhone" "SKTFindLostPhoneApp"
"SKTHiddenMenu" "SKTOneStore" "SktUsimService"

"LGUMiniCustomerCenter" "LGUplusTsmProxy"
"LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore"

"TWorld" "TService" "TPhoneOnePackage" "TPhoneSetup"

# --- System ---
"BluetoothMidiService" "PrintSpooler" "WebManual"
"WifiGuider" "UltraDataSaving_O" "Upday"

# --- Facebook ---
"FBAppManager_NS" "FBInstaller_NS" "FBServices"

# --- Preload ---
"Netflix_stub"

# --- Extra ---
"SetupIndiaServicesTnC" "SamsungPass"
"SamsungPassAutofill_v1" "SamsungBilling"
"UniversalMDMClient" "Discover" "DiscoverSEP"
"DigitalKey" "EarphoneTypeC"
"SamsungCarKeyFw"

# --- Accessibility ---
"TalkbackSE" "SwiftkeyIme"

# --- Low-level system ---
"vexfwk_service" "VexScanner" "LiveEffectService"

# --- Removed by YOU ---
"AppCloud" "SamsungStore" "MyGalaxy"
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

    echo -e "${YELLOW}Starting Aggressive Debloat...${NC}"

    KICK "$DIR"
    REMOVE_ESIM_FILES "$DIR"
    REMOVE_FABRIC_CRYPTO "$DIR"
    CLEAN_RESIDUAL_FILES "$DIR"
    OPTIMIZE_BUILD_PROP "$DIR"

    echo -e "${YELLOW}Debloat Complete (Performance Mode).${NC}"
}
