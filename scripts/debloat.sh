#!/bin/bash

###################################################################################################
# COLORS
###################################################################################################

RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

###################################################################################################
# FINAL AGGRESSIVE DEBLOAT LIST
###################################################################################################

DEBLOAT_APPS=(

# --- Google / AOSP ---
"SpeechServicesByGoogle"
"LiveTranscribe"
"DigitalWellbeing"
"Maps"
"Duo"
"Photos"
"AssistantShell"
"BardShell"
"DuoStub"
"GoogleCalendarSyncAdapter"
"AndroidDeveloperVerifier"
"GoogleRestore"
"SearchSelector"
"VoiceAccess"

# --- Extra Google Debloat ---
"Drive"
"GoogleOne"
"BackupRestoreConfirmation"
"Videos"
"Music2"
"ChromeCustomizations"
"Velvet"
"LocationHistory"
"LocationSharing"
"YouTube"
"YouTubeMusicPrebuilt"
"PrebuiltGemini"

# --- Samsung Core ---
"SamsungCalendar"
"Notes40"
"SamsungMembers"
"Tips"
"VoiceNote_5.0"

# --- Samsung Ecosystem ---
"MdecService"
"LinkToWindowsService"
"SmartThingsKit"
"SmartSwitchStub"
"OneDrive_Samsung_v3"

# --- Knox ---
"KnoxEnrollmentService"
"KnoxPushManager"
"KLMSAgent"

# --- Gaming ---
"GameOptimizerService"
"GameTools_Dream"
"GameHome"

# --- VPN / Network ---
"SamsungMax"
"SamsungVPN"

# --- AR / Camera ---
"ARCore"
"ARDrawing"
"ARZone"
"AREmoji"
"AREmojiEditor"
"AvatarEmojiSticker"
"AvatarEmojiSticker_S"
"StickerFaceARAvatar"
"LiveStickers"

# --- Bixby ---
"Bixby"
"BixbyWakeup"
"BixbyInterpreter"
"BixbyVisionFramework3.5"
"SettingsBixby"

# --- Analytics ---
"DiagMonAgent"
"SamsungAnalytics"
"SOAgent7"
"SOAgent75"
"SOAgent76"
"SOAgent77"

# --- UI / Features ---
"EdgeLighting"
"PeopleStripe"
"AirGlance"
"AirReadingGlass"
"SmartSuggestions"
"SamsungSmartSuggestions"

# --- Misc ---
"LiveDrawing"
"PhotoTable"
"VideoEditorLite_Dream_N"
"GalleryWidget"
"EasySetup"
"KidsHome_Installer"
"ParentalCare"
"SmartReminder"
"StickerCenter"
"SmartPush"
"SmartPush_64"

# --- Carrier ---
"KTAuth"
"KTCustomerService"
"KTUsimManager"
"KTServiceAgent"
"KTServiceMenu"
"KT114Provider2"
"KTHiddenMenu"
"KTOneStore"

"SKTMemberShip"
"SKTMemberShip_new"
"SKTFindLostPhone"
"SKTFindLostPhoneApp"
"SKTHiddenMenu"
"SKTOneStore"
"SktUsimService"

"LGUMiniCustomerCenter"
"LGUplusTsmProxy"
"LGUGPSnWPS"
"LGUHiddenMenu"
"LGUOZStore"

"TWorld"
"TService"
"TPhoneOnePackage"
"TPhoneSetup"

# --- Connectivity ---
"LinkSharing_v11"
"QuickShare"

# --- System ---
"BluetoothMidiService"
"PrintSpooler"
"WebManual"
"WifiGuider"
"UltraDataSaving_O"
"Upday"

# --- Facebook ---
"FBAppManager_NS"
"FBInstaller_NS"
"FBServices"

# --- Preload ---
"Netflix_stub"

# --- Extra ---
"SetupIndiaServicesTnC"
"SamsungPass"
"SamsungPassAutofill_v1"
"SamsungBilling"
"SystemUpdate"

# --- Accessibility ---
"TalkbackSE"
"SwiftkeyIme"
"SamsungTTS"

# --- Removed by YOU ---
"AppCloud"
"SamsungStore"
"MyGalaxy"
)

###################################################################################################
# REMOVE APPS
###################################################################################################

KICK() {
    local DIR="$1"
    echo "- Removing selected apps."

    local APP_DIRS=(
        "$DIR/system/system/app"
        "$DIR/system/system/priv-app"
        "$DIR/product/app"
        "$DIR/product/priv-app"
    )

    for app in "${DEBLOAT_APPS[@]}"; do
        for base in "${APP_DIRS[@]}"; do
            target="$base/$app"
            if [[ -d "$target" ]]; then
                echo "  Removing: $target"
                rm -rf "$target"
            fi
        done
    done
}

###################################################################################################
# REMOVE FABRIC CRYPTO
###################################################################################################

REMOVE_FABRIC_CRYPTO() {
    local DIR="$1"
    echo "- Removing fabric crypto."

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
# CLEAN
###################################################################################################

CLEAN_RESIDUAL_FILES() {
    local DIR="$1"
    echo "- Cleaning residual files."

    find "$DIR/product/app" -type d -name "oat" -exec rm -rf {} +
    find "$DIR/product/priv-app" -type d -name "oat" -exec rm -rf {} +

    rm -rf "$DIR/system/system/etc/sync"
    rm -rf "$DIR/system/system/log"
}

###################################################################################################
# BUILD.PROP
###################################################################################################

OPTIMIZE_BUILD_PROP() {
    local FILE="$1/system/system/build.prop"
    echo "- Applying performance tweaks."

    grep -q "persist.sys.logd.enable" "$FILE" || echo "persist.sys.logd.enable=0" >> "$FILE"
    grep -q "windowsmgr.max_events_per_sec" "$FILE" || echo "windowsmgr.max_events_per_sec=90" >> "$FILE"
}

###################################################################################################
# MAIN
###################################################################################################

DEBLOAT() {
    if [ "$#" -ne 1 ]; then
        echo -e "${RED}Usage: DEBLOAT <EXTRACTED_FIRM_DIR>${NC}"
        return 1
    fi

    local DIR="$1"

    echo -e "${YELLOW}Starting Aggressive Debloat...${NC}"

    KICK "$DIR"
    REMOVE_FABRIC_CRYPTO "$DIR"
    CLEAN_RESIDUAL_FILES "$DIR"
    OPTIMIZE_BUILD_PROP "$DIR"

    echo -e "${YELLOW}Debloat complete (Ultra Aggressive Mode).${NC}"
}
