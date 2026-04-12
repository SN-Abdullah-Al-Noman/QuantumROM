#!/bin/bash

###################################################################################################
# COLORS
###################################################################################################

RED="\e[31m"
YELLOW="\e[33m"
NC="\e[0m"

###################################################################################################
# FINAL BALANCED DEBLOAT LIST (SAFE + PERFORMANCE)
###################################################################################################

DEBLOAT_APPS=(

# --- Google (safe to remove) ---
"DigitalWellbeing"
"LiveTranscribe"

# --- Samsung Optional Apps ---
"SamsungMembers"
"Tips"
"VoiceNote_5.0"

# --- AR / Camera extras ---
"AREmoji"
"AREmojiEditor"
"AvatarEmojiSticker"
"AvatarEmojiSticker_S"
"ARZone"
"ARDrawing"

# --- Bixby (safe partial removal) ---
"BixbyWakeup"
"BixbyVisionFramework3.5"

# --- Logging / Analytics (HIGH IMPACT, SAFE) ---
"DiagMonAgent"
"SamsungAnalytics"

# --- Edge features (optional UI only) ---
"EdgeLighting"
"PeopleStripe"

# --- Game services ---
"GameTools"

# --- Printing / misc ---
"PrintSpooler"
"BluetoothMidiService"

# --- Minor background services ---
"StickerCenter"
"SmartSuggestions"

# --- User-approved removals ---
"MdecService"
"LinkToWindowsService"
"SmartThingsKit"
"SamsungCalendar"
"Notes40"

# --- Extra safe removals ---
"LiveDrawing"
"PhotoTable"
"VideoEditorLite_Dream_N"
"GalleryWidget"
"EasySetup"
"KidsHome_Installer"
"ParentalCare"
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
# CLEAN RESIDUAL FILES
###################################################################################################

CLEAN_RESIDUAL_FILES() {
    local DIR="$1"
    echo "- Cleaning residual files."

    # Remove unused oat (compiled cache)
    find "$DIR/product/app" -type d -name "oat" -exec rm -rf {} +
    find "$DIR/product/priv-app" -type d -name "oat" -exec rm -rf {} +

    # Remove leftover sync configs (SAFE)
    rm -rf "$DIR/system/system/etc/sync"

    # Remove log cache (SAFE)
    rm -rf "$DIR/system/system/log"
}

###################################################################################################
# BUILD.PROP OPTIMIZATION (SAFE ONLY)
###################################################################################################

OPTIMIZE_BUILD_PROP() {
    local FILE="$1/system/system/build.prop"
    echo "- Applying performance tweaks."

    # Disable excessive logging
    grep -q "persist.sys.logd.enable" "$FILE" || echo "persist.sys.logd.enable=0" >> "$FILE"

    # Improve touch responsiveness
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

    echo -e "${YELLOW}Starting Balanced Performance Debloat...${NC}"

    KICK "$DIR"
    CLEAN_RESIDUAL_FILES "$DIR"
    OPTIMIZE_BUILD_PROP "$DIR"

    echo -e "${YELLOW}Debloat complete (Stable + Optimized).${NC}"
}
