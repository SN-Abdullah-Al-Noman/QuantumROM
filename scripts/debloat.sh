#!/bin/bash


# GENERAL / SYSTEM / BLOAT
DEBLOAT_APPS=(
"HMT" "PaymentFramework" "DigitalWellbeing" "FactoryCameraFB"
"WlanTest" "AirGlance" "AirReadingGlass" "AndroidGlassesCore"
"SOAgent77" "ARCore" "ARDrawing" "ARZone" "BGMProvider"
"SingleTakeService" "BixbyWakeup" "BlockchainBasicKit"
"Cameralyzer" "DictDiotekForSec" "EasymodeContactsWidget81"
"Fast" "FunModeSDK" "GearManagerStub" "KidsHome_Installer"
"LinkSharing_v11" "LiveDrawing" "MAPSAgent" "MdecService"
"MinusOnePage" "MoccaMobile" "Netflix_stub" "Notes40"
"ParentalCare" "PhotoTable" "SmartReminder" "SmartSwitchStub"
"UnifiedWFC" "UniversalMDMClient" "VideoEditorLite_Dream_N"
"VisionIntelligence3.7" "VoiceAccess" "VTCameraSetting"
"WebManual" "WifiGuider" "AutomationTest_FB" "FactoryTestProvider"
"StickerCenter" "CIDManager" "FacAtFunction" "serviceModeApp_FB"
)


# KOREAN / CARRIER APPS
CARRIER_APPS=(
"KTAuth" "KTCustomerService" "KTUsimManager"
"LGUMiniCustomerCenter" "LGUplusTsmProxy"
"SKTMemberShip_new" "SktUsimService" "TWorld"
"KT114Provider2" "KTHiddenMenu" "KTOneStore"
"KTServiceAgent" "KTServiceMenu"
"LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore"
"SKTFindLostPhone" "SKTHiddenMenu" "SKTMemberShip"
"SKTOneStore" "SKTFindLostPhoneApp"
"TPhoneOnePackage" "TPhoneSetup" "TService"
"UsimRegistrationKOR" "HpsAgreement_new" "KTAuth_Stub"
)


# SAMSUNG FEATURES / APPS
SAMSUNG_APPS=(
"SamsungCalendar" "SamsungTTS" "SamsungBilling"
"OneDrive_Samsung_v3" "SamsungCarKeyFw"
"SamsungPass" "SamsungSmartSuggestions"
"SamsungPassAutofill_v1"
"AirCommand" "AppUpdateCenter" "AREmoji"
"AREmojiEditor" "AutoDoodle" "AvatarEmojiSticker"
"AvatarEmojiSticker_S" "AvatarPicker"
"GalleryWidget" "LiveStickers" "StoryService"
"StickerFaceARAvatar" "sticker"
)


# SAMSUNG AI / SMART
SAMSUNG_AI=(
"LiveTranscribe" "Bixby" "BixbyInterpreter"
"BixbyVisionFramework3.5" "SettingsBixby"
"SmartEye" "SmartPush" "SmartPush_64"
"SmartThingsKit" "SmartTouchCall"
"VisionIntelligence3.7"
)


# GOOGLE APPS
GOOGLE_APPS=(
"SpeechServicesByGoogle" "Maps" "Duo" "Photos"
"AssistantShell" "BardShell" "DuoStub"
"GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier"
"YourPhone_Stub" "AndroidAutoStub" "FamilyLinkParentalControls"
"AndroidSystemIntelligence" "GoogleRestore"
"SamsungMessages" "SearchSelector" "PlayAutoInstallConfig" "FamilyLinkParentalControls"
)


# FACEBOOK
FACEBOOK_APPS=(
"FBAppManager_NS" "FBInstaller_NS" "FBServices"
)


# DRIVERS
HARDWARE_DRIVERS=(
"DevGPUDriver-EX2200"
"GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150"
)


# MISC / SERVICES
MISC_SERVICES=(
"AuthFramework" "Discover" "DiscoverSEP"
"EarphoneTypeC" "EasySetup" "FotaAgent"
"HashTagService" "LedCoverService"
"LinkToWindowsService" "MemorySaver_O_Refresh"
"MultiControl" "MultiControlVP6"
"OMCAgent5" "OneStoreService" "FactoryAirCommandManager"
"SOAgent7" "SOAgent75" "SOAgent76"
"SolarAudio-service" "SPPPushClient"
"SumeNNService" "SVoiceIME"
"SwiftkeyIme" "SwiftkeySetting"
"SystemUpdate" "TADownloader"
"TalkbackSE" "TaPackAuthFw"
"UltraDataSaving_O" "Upday"
"YourPhone_P1_5" "DsmsAPK"
"vexfwk_service" "VexScanner"
"LiveEffectService" "MyGalaxyService"
)


# Knox
KNOX_APPS=("Rampart" "KnoxFrameBufferProvider")


REMOVE_ESIM_FILES() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing ESIM files."
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/autoinstalls/autoinstalls-com.google.android.euicc"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/default-permissions/default-permissions-com.google.android.euicc.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.euicc.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.esimkeystring.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/privapp-permissions-com.samsung.android.app.telephonyui.esimclient.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.euicc.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/preinstalled-packages-com.samsung.android.app.esimkeystring.xml"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimClient"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EsimKeyString"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccService"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/EuiccGoogle"
}


REMOVE_FABRIC_CRYPTO() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
    echo -e "- Removing fabric crypto."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/bin/fabric_crypto"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/fabric_crypto.rc"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/permissions/FabricCryptoLib.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/vintf/manifest/fabric_crypto_manifest.xml"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/FabricCryptoLib.jar"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.odex"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm/FabricCryptoLib.vdex"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.odex"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/framework/oat/arm64/FabricCryptoLib.vdex"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/com.samsung.security.fabric.cryptod-V1-cpp.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/lib64/vendor.samsung.hardware.security.fkeymaster-V1-ndk.so"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/KmxService"
}


KICK() {
    if [ "$#" -lt 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <APPS...>"
        return 1
    fi
    
    local EXTRACTED_FIRM_DIR="$1"
    shift
    local APPS_LIST=("$@")

    local APP_DIRS=(
        "$EXTRACTED_FIRM_DIR/system/system/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/product/app"
        "$EXTRACTED_FIRM_DIR/product/priv-app"
    )

    for app in "${APPS_LIST[@]}"; do
        for dir in "${APP_DIRS[@]}"; do
            target="$dir/$app"

            if [[ -d "$target" ]]; then
                rm -rf "$target" || echo -e "[WARN] Failed to delete $target"
            fi
        done
    done
}


DEBLOAT() {
    echo -e ""
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

	if [ ! -d "$EXTRACTED_FIRM_DIR/system" ]; then
	    echo -e "No extracted firmware found."
        return 1
    fi

    echo -e "Debloating apps and files."

	# Debloat apps
	echo "- Debloating apps."
    KICK "$EXTRACTED_FIRM_DIR" "${DEBLOAT_APPS[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${CARRIER_APPS[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${SAMSUNG_APPS[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${SAMSUNG_AI[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${GOOGLE_APPS[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${FACEBOOK_APPS[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${HARDWARE_DRIVERS[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${MISC_SERVICES[@]}"
    KICK "$EXTRACTED_FIRM_DIR" "${KNOX_APPS[@]}"
	REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"

	echo -e "- Deleting unnecessary files and folders."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/app"/SamsungTTS*
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.bprof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.prof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/hidden"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/preload"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/mediasearch"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/MediaSearch"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/GameDriver-*
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/skt"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/tts"
	rm -rf "$EXTRACTED_FIRM_DIR/product/app/Gmail2/oat"
    rm -rf "$EXTRACTED_FIRM_DIR/product/app/Maps/oat"
	rm -rf "$EXTRACTED_FIRM_DIR/product/app/SpeechServicesByGoogle/oat"
	rm -rf "$EXTRACTED_FIRM_DIR/product/app/YouTube/oat"
	rm -rf "$EXTRACTED_FIRM_DIR/product/priv-app"/HotwordEnrollment*
}
