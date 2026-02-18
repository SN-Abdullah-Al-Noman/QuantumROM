#!/bin/bash

###################################################################################################
# REAL_USER=${SUDO_USER:-$USER}

export TARGET_FLOATING_FEATURE="$FIRM_DIR/$TARGET_DEVICE/system/system/etc/floating_feature.xml"

CHECK_FILE() {
    if [ ! -f "$1" ]; then
        echo "[!] File not found: $1"
        echo "- Skipping..."
        return 1
    fi
    return 0
}


REMOVE_LINE() {
    if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <TARGET_LINE> <TARGET_FILE>"
        return 1
    fi

    local LINE="$1"
    local FILE="$2"

    echo "- Deleting $LINE from $FILE"
    grep -vxF "$LINE" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}


DOWNLOAD_FIRMWARE() {
    if [ "$#" -ne 4 ]; then
        echo "Usage: ${FUNCNAME[0]} <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY>"
        return 1
    fi

    local MODEL=$1
    local CSC=$2
    local IMEI=$3
    local DOWN_DIR="${4}/$MODEL"

	rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo "======================================"
    echo "  Samsung FW Downloader   "
    echo "======================================"
    echo "MODEL: $MODEL | CSC: $CSC"
    echo "Fetching latest firmware..."
    echo

    # --- Step 1: Check Update ---
    version=$(python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" checkupdate 2>&1)
    if [ $? -ne 0 ] || [ -z "$version" ]; then
        echo "❌ MODEL/CSC/IMEI not valid or no update found."
        echo "Error: $version"
        return 1
    else
        echo "✅ Update found: $version"
    fi

    # --- Step 2: Download Firmware ---
    python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" download -v "$version" -O "$DOWN_DIR"
    if [ $? -ne 0 ]; then
        echo "❌ Download failed. Check IMEI/MODEL/CSC."
        return 1
    fi

    # --- Step 3: Decrypt Firmware ---
    enc_file=$(find "$DOWN_DIR" -name "*.enc*" | head -n 1)

    if [ -z "$enc_file" ]; then
        echo "❌ No encrypted firmware file found!"
        return 1
    fi

    python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" decrypt \
        -v "$version" \
        -i "$enc_file" \
        -o "${DOWN_DIR}/${MODEL}.zip" >/dev/null 2>&1

    if [ $? -ne 0 ]; then
        echo "❌ Decryption failed."
        return 1
    fi

    # --- Show Firmware Info ---
    file_size=$(du -m "${DOWN_DIR}/${MODEL}.zip" | cut -f1)
    echo
    echo "✅ Firmware decrypted successfully!. Firmware Size: ${file_size} MB"
    echo "Saved to: ${DOWN_DIR}/${MODEL}.zip"

    # --- Cleanup ---
    rm -f "$enc_file"
}


EXTRACT_FIRMWARE() {
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"

    echo "Extracting downloaded firmware."
    echo "- Extracting zip file."
    find "$FIRM_DIR" -maxdepth 1 -name "*.zip" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -rf "$FIRM_DIR"/*.zip

    echo "- Extracting xz file."
    find "$FIRM_DIR" -maxdepth 1 -name "*.xz" \
        -exec 7z x -y -bd -o"$FIRM_DIR" {} \; >/dev/null 2>&1
    rm -rf "$FIRM_DIR"/*.xz

    # ---- MD5 rename ----
    find "$FIRM_DIR" -maxdepth 1 -name "*.md5" \
        -exec sh -c 'mv -- "$1" "${1%.md5}"' _ {} \;

    echo "- Extracting tar files..."
    for file in "${FIRM_DIR}"/*.tar; do
        if [ -f "$file" ]; then
            tar -xvf "$file" -C "${FIRM_DIR}" >/dev/null 2>&1
            rm -f "$file"
        fi
    done

    echo "- Extracting lz4 file."
	for file in "${FIRM_DIR}"/*.lz4; do
        [ -f "$file" ] && lz4 -d "$file" "${file%.lz4}" >/dev/null 2>&1
    done
    rm -rf "${FIRM_DIR}"/*.lz4

    # ---- REMOVE UNWANTED FILES ----
    rm -rf \
        "$FIRM_DIR"/*.txt \
        "$FIRM_DIR"/*.pit \
        "$FIRM_DIR"/*.bin \
        "$FIRM_DIR"/meta-data

    if [ -f "$FIRM_DIR/super.img" ]; then
        echo "- Extracting super.img"
        simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super.img"
        lpunpack -o "$FIRM_DIR" "$FIRM_DIR/super_raw.img"
        rm -f "$FIRM_DIR/super_raw.img"
        echo "- Extraction complete"
    fi
}


PREPARE_PARTITIONS() {
    echo ""
	if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        export BUILD_PARTITIONS="odm,product,system_ext,system,vendor"
    fi

    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    [[ -z "$EXTRACTED_FIRM_DIR" || ! -d "$EXTRACTED_FIRM_DIR" ]] && {
        echo "Invalid directory: $EXTRACTED_FIRM_DIR"
        return 1
    }

    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"

    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo "${KEEP[$i]}" | xargs)
    done

    echo "Preparing partitinos."

    shopt -s nullglob dotglob

    for item in "$EXTRACTED_FIRM_DIR"/*; do
        base=$(basename "$item")

        [[ "$base" == *.img ]] && base="${base%.img}"

        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done

        if [[ $keep_this -eq 0 ]]; then
            # echo "- Deleting: $item"
            rm -rf -- "$item"
        else
            echo "- Keeping: $item"
        fi
    done

    shopt -u nullglob dotglob
}


EXTRACT_FIRMWARE_IMG() {
    echo ""
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

	local FIRM_DIR="$1"
	PREPARE_PARTITIONS "$FIRM_DIR"

	echo "Extracting imges from $FIRM_DIR"
    for imgfile in "$FIRM_DIR"/*.img; do
        [ -e "$imgfile" ] || continue

        if [[ "$(basename "$imgfile")" == "boot.img" ]]; then
            continue
        fi

        local partition
        local fstype
        local IMG_SIZE

        partition="$(basename "${imgfile%.img}")"
        fstype=$(file -b $imgfile | awk '{print $1}')

        case "$fstype" in
            ext4)
                IMG_SIZE=$(stat -c%s -- "$imgfile")
				echo "$imgfile Detected $fstype. Size: $IMG_SIZE bytes."
                echo "Extracting $imgfile in $FIRM_DIR/$partition"
				rm -rf "$FIRM_DIR/$partition"
                python3 $(pwd)/bin/py_scripts/imgextractor.py "$imgfile" "$FIRM_DIR"
                ;;
            EROFS)
                echo ""
                IMG_SIZE=$(stat -c%s -- "$imgfile")
                echo "$imgfile Detected $fstype. Size: $IMG_SIZE bytes."
                echo "Extracting $imgfile in $FIRM_DIR/$partition"
				rm -rf "$FIRM_DIR/$partition"
                $(pwd)/bin/erofs-utils/extract.erofs -i "$imgfile" -x -f -o "$FIRM_DIR" >/dev/null 2>&1
                ;;
            *)
                echo "[$imgfile] Unknown filesystem type ($fstype), skipping"
                return 1
                ;;
        esac
    done

    rm -rf "$FIRM_DIR"/*.img

    # sudo chown -R "$REAL_USER:$REAL_USER" "$FIRM_DIR/config"
    # chmod -R u+rwX "$FIRM_DIR/config"
}


DISABLE_FBE() {
    local EXTRACTED_FIRM_DIR="$1"
    
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local md5
    local i
    fstab_files=`grep -lr 'fileencryption' $EXTRACTED_FIRM_DIR/vendor/etc`

    #
    # Exynos devices = fstab.exynos*.
    # MediaTek devices = fstab.mt*.
    # Snapdragon devices = fstab.qcom, fstab.emmc, fstab.default
    #
    for i in $fstab_files; do
      if [ -f $i ]; then
        echo "Disabling file-based encryption (FBE) for /data..."
        echo "- Found $i."
        # This comments out the offending line and adds an edited one.
        sed -i -e 's/^\([^#].*\)fileencryption=[^,]*\(.*\)$/# &\n\1encryptable\2/g' $i
      fi
    done
}


DISABLE_FDE() {
    local EXTRACTED_FIRM_DIR="$1"
 	
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local md5
    local i
    fstab_files=`grep -lr 'forceencrypt' $EXTRACTED_FIRM_DIR/vendor/etc`

    #
    # Exynos devices = fstab.exynos*.
    # MediaTek devices = fstab.mt*.
    # Snapdragon devices = fstab.qcom, fstab.emmc, fstab.default
    #
    for i in $fstab_files; do
      if [ -f $i ]; then
        echo "Disabling full-disk encryption (FDE) for /data..."
        echo "- Found $i."
        md5=$( md5 $i )
        # This comments out the offending line and adds an edited one.
        sed -i -e 's/^\([^#].*\)forceencrypt=[^,]*\(.*\)$/# &\n\1encryptable\2/g' $i
        file_changed $i $md5
      fi
    done
}


INSTALL_FRAMEWORK() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <framework-res.apk>"
        return 1
    fi

    echo ""
    local framework_res_apk="$1"
    echo "Installing Framework."
    java -jar "$APKTOOL" install-framework "$framework_res_apk"
}


DECOMPILE() {
    echo ""
    if [ "$#" -ne 3 ]; then
        echo "Usage: DECOMPILE <APKTOOL_JAR_DIR> <FILE> <DECOMPILE_DIR>"
        return 1
    fi

    local APKTOOL="$1"
    local FILE="$2"
    local DECOMPILE_DIR="$3"
    local BASENAME="$(basename "${FILE%.*}")"
    local OUT="$DECOMPILE_DIR/$BASENAME"

    echo "Decompiling: $FILE"
	rm -rf "$OUT"
    java -jar "$APKTOOL" d -f "$FILE" -o "$OUT"
}


RECOMPILE() {
    echo ""
	if [ "$#" -ne 4 ]; then
        echo "Usage: ${FUNCNAME[0]} <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <DECOMPILED_DIR> <RECOMPILE_DIR>"
        return 1
    fi

	local APKTOOL="$1"
	local DECOMPILED_DIR="$2"
    local FRAMEWORK_DIR="$3"
    local RECOMPILE_DIR="$4"

    local org_file_name
    org_file_name=$(awk '/^apkFileName:/ {print $2}' "$DECOMPILED_DIR/apktool.yml")
    local name="${org_file_name%.*}"
    local ext="${org_file_name##*.}"
    local built_file="$WORK_DIR/${name}_unsigned.$ext"
    local final_file="$WORK_DIR/$org_file_name"

    echo "Recompiling: $DECOMPILED_DIR"
    java -jar "$APKTOOL" b "$DECOMPILED_DIR" --copy-original -p "$FRAMEWORK_DIR" -o "$built_file"

    # Zipalign
	echo ""
	if [[ "$ext" == "jar" ]]; then
	    echo "Zipaligning: $built_file to $final_file"
        zipalign -v 4 "$built_file" "$final_file" >/dev/null 2>&1
		rm -rf "$built_file" "$DECOMPILED_DIR"
    fi
}


REPLACE_SMALI_METHOD() {
    local FILE="$1"
    local METHOD_NAME="$2"
    local NEW_BODY=$(echo "$3" | tail -n +2)

    # Escape special chars in method name for sed
    local method_esc
    method_esc=$(printf '%s\n' "$METHOD_NAME" | sed -e 's/[.[\*^$/]/\\&/g')

    echo "- Patching $FILE"

    sed -i "
/^[[:space:]]*$method_esc\$/,/^[[:space:]]*\.end method/{
    /^[[:space:]]*$method_esc\$/{
        p
        r /dev/stdin
        d
    }
    /^[[:space:]]*\.end method/p
    d
}" "$FILE" <<< "$NEW_BODY"
}


HEX_PATCH() {
    echo ""
	if [ "$#" -ne 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <FILE> <TARGET_VALUE> <REPLACE_VALUE>"
        return 1
    fi

    local FILE="$1"
    local FROM="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    local TO="$(echo "$3" | tr '[:upper:]' '[:lower:]')"

    [ ! -f "$FILE" ] && { echo "File not found: $FILE"; return 1; }

    xxd -p -c 0 "$FILE" | grep -q "$FROM" || {
        echo "- Pattern not found: $FROM"
        return 1
    }

    echo "- Patching: $FILE"
    echo "- From $FROM to $TO"
    [ -f "$FILE.bak" ] || cp "$FILE" "$FILE.bak"

    xxd -p -c 0 "$FILE" | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp" &&
    mv "$FILE.tmp" "$FILE"

    xxd -p -c 0 "$FILE" | grep -q "$TO" && {
        echo "- Patch success"
        rm -rf "$FILE.bak"        
        return 0
    }

    echo "- Patch failed, restoring backup"
    mv "$FILE.bak" "$FILE"
    return 1
}


PATCH_FLAG_SECURE() {
	echo ""
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

	echo "Patching flag secure."
	local FILE="${1}/smali_classes2/com/android/server/wm/WindowState.smali"
    local METHOD_NAME_1=".method public final isSecureLocked()Z"
    local REPLACE_BODY_1='
    .locals 1

    const/4 v0, 0x0

    return v0
    '
    REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME_1" "$REPLACE_BODY_1"
    
    local METHOD_NAME_2=".method public final notifyScreenshotListeners(I)Ljava/util/List;"
    local REPLACE_BODY_2='
    .locals 3
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "(I)",
            "Ljava/util/List<",
            "Landroid/content/ComponentName;",
            ">;"
        }
    .end annotation

    const-string/jumbo v0, "android.permission.STATUS_BAR_SERVICE"

    const-string/jumbo v1, "notifyScreenshotListeners()"

    const/4 v2, 0x1

    invoke-virtual {p0, v0, v1, v2}, Lcom/android/server/wm/WindowManagerService;->checkCallingPermission$1(Ljava/lang/String;Ljava/lang/String;Z)Z

    move-result v0

    if-eqz v0, :cond_43

    invoke-static {}, Ljava/util/Collections;->emptyList()Ljava/util/List;

    move-result-object p0

    return-object p0

    :cond_43
    new-instance p0, Ljava/lang/SecurityException;

    const-string/jumbo p1, "Requires STATUS_BAR_SERVICE permission"

    invoke-direct {p0, p1}, Ljava/lang/SecurityException;-><init>(Ljava/lang/String;)V

    throw p0
'    
    REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME_2" "$REPLACE_BODY_2"
}


PATCH_SECURE_FOLDER() {
    echo ""
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo "Patching secure folder."
    local FILE="${1}/smali/com/android/server/knox/dar/DarManagerService.smali"
    # patch isDeviceRootKeyInstalled
    local METHOD_NAME_1=".method public final isDeviceRootKeyInstalled()Z"
    local REPLACE_BODY_1='
    .locals 0

    const/4 v0, 0x1

    return v0
    '
    REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME_1" "$REPLACE_BODY_1"

    # patch isKnoxKeyInstallable
    local METHOD_NAME_2=".method public final isKnoxKeyInstallable()Z"
    local REPLACE_BODY_2='
    .locals 0

    const/4 v0, 0x1

    return v0
    '
    REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME_2" "$REPLACE_BODY_2"
}


PATCH_KNOX_GUARD() {
    echo ""
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo "Patching knox guard."
    local FILE="${1}/smali_classes2/com/samsung/android/knoxguard/service/KnoxGuardSeService.smali"
    # patch .method public constructor <init>(Landroid/content/Context;)V
    local METHOD_NAME_1=".method public constructor <init>(Landroid/content/Context;)V"
    local REPLACE_BODY_1='
    .locals 0
 
	invoke-direct {p0}, Lcom/samsung/android/knoxguard/IKnoxGuardManager$Stub;-><init>()V
 
    const/4 p1, 0x0
 
    iput-object p1, p0, Lcom/samsung/android/knoxguard/service/KnoxGuardSeService;->mConnectivityManagerService:Landroid/net/ConnectivityManager;
 
    new-instance p0, Ljava/lang/UnsupportedOperationException;
 
    const-string p1, "KnoxGuard is disabled"
 

    invoke-direct {p0, p1}, Ljava/lang/UnsupportedOperationException;-><init>(Ljava/lang/String;)V

    throw p0
    '
    REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME_1" "$REPLACE_BODY_1"
	rm -rf "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app/KnoxGuard"
}


UPDATE_SDHMS() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local TARGET_APK="$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"
    local ALT_APK="$(pwd)/QuantumROM/Mods/SDHMS/system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"

    if [ -f "$TARGET_APK" ] && zipinfo -1 "$TARGET_APK" 2>/dev/null | grep -q "^res/raw/${STOCK_DVFS_FILENAME}\.xml$"; then
        echo "$STOCK_DEVICE Dynamic Voltage and Frequency Scaling table: ${STOCK_DVFS_FILENAME}.xml found in current SDHMS app"
    elif [ -f "$ALT_APK" ] && zipinfo -1 "$ALT_APK" 2>/dev/null | grep -q "^res/raw/${STOCK_DVFS_FILENAME}\.xml$"; then
        echo "$STOCK_DEVICE Dynamic Voltage and Frequency Scaling table: ${STOCK_DVFS_FILENAME}.xml found in alternative APK. Replacing in target ROM"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungDeviceHealthManagerService"
        cp -a "$(pwd)/QuantumROM/Mods/SDHMS/." "$EXTRACTED_FIRM_DIR/"
    else
        echo "$STOCK_DEVICE Dynamic Voltage and Frequency Scaling table: ${STOCK_DVFS_FILENAME}.xml not found anywhere"
    fi
}


PATCH_SSRM() {
    echo ""
	if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_SSRM_DIRECTORY>"
        return 1
    fi

    local SSRM_DIR="$1"
	local FILE="$SSRM_DIR/smali/com/android/server/ssrm/Feature.smali"

	echo "Patching ssrm.jar"
	echo "- Updating stock SIOP_FILENAME > $STOCK_SIOP_FILENAME and STOCK_DVFS_FILENAME > $STOCK_DVFS_FILENAME in ssrm.jar"
	echo "  $FILE"

    sed -i "s/\(const-string v[0-9]\+,\s*\"\)siop_[^\"]*\"/\1$STOCK_SIOP_FILENAME\"/g" "$FILE"
    sed -i "/dvfs_policy_default/! s/\(const-string v[0-9]\+,\s*\"\)dvfs_policy_[^\"]*\"/\1$STOCK_DVFS_FILENAME\"/g" "$FILE"

    # UPDATE_SDHMS "$FIRM_DIR/$TARGET_DEVICE"
}


PATCH_BT_LIB() {
    echo ""
	if [ "$#" -ne 2 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY> <WORK_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local WORK_DIR="$2"
	local BT_LIB_FILE="$WORK_DIR/libbluetooth_jni.so"

    echo "Patching Bluetooth library."
    # Get libbluetooth_jni.so
    unzip "$EXTRACTED_FIRM_DIR/system/system/apex/com.android.bt.apex" "apex_payload.img" -d "$WORK_DIR"
	debugfs -R "dump /lib64/libbluetooth_jni.so $WORK_DIR/libbluetooth_jni.so" "$WORK_DIR/apex_payload.img"  >/dev/null 2>&1
	rm -rf "$WORK_DIR/apex_payload.img"

    # local associative array (function-scoped)
    declare -A hex=(
        [136]=00122a0140395f01086b00020054 [1136]=00122a0140395f01086bde030014
        [135]=480500352800805228 [1135]=530100142800805228
        [134]=6804003528008052 [1134]=2b00001428008052
        [133]=6804003528008052 [1133]=2a00001428008052
        [132]=........f9031f2af3031f2a41 [1132]=1f2003d5f9031f2af3031f2a48
        [131]=........f9031f2af3031f2a41 [1131]=1f2003d5f9031f2af3031f2a48
        [130]=........f3031f2af4031f2a3e [1130]=1f2003d5f3031f2af4031f2a3e
        [129]=........f4031f2af3031f2ae8030032 [1129]=1f2003d5f4031f2af3031f2ae8031f2a
        [128]=88000034e8030032 [1128]=1f2003d5e8031f2a
        [127]=88000034e8030032 [1127]=1f2003d5e8031f2a
        [126]=88000034e8030032 [1126]=1f2003d5e8031f2a
        [234]=4e7e4448bb [1234]=4e7e4437e0
        [233]=4e7e4440bb [1233]=4e7e4432e0
        [231]=20b14ff000084ff000095ae0 [1231]=00bf4ff000084ff0000964e0
        [230]=18b14ff0000b00254a [1230]=00204ff0000b002554
        [229]=..b100250120 [1229]=00bf00250020
        [228]=..b101200028 [1228]=00bf00200028
        [227]=09b1012032e0 [1227]=00bf002032e0
        [226]=08b1012031e0 [1226]=00bf002031e0
        [225]=087850bbb548 [1225]=08785ae1b548
        [224]=007840bb6a48 [1224]=0078c4e06a48
        [330]=88000054691180522925c81a69000037 [1330]=1f2003d5691180522925c81a1f2003d5
        [329]=88000054691180522925c81a69000037 [1329]=1f2003d5691180522925c81a1f2003d5
        [328]=7f1d0071e91700f9e83c0054 [1328]=7f1d0071e91700f9e7010014
        [429]=....0034f3031f2af4031f2a....0014 [1429]=1f2003d5f3031f2af4031f2a47000014
        [531]=10b1002500244ce0 [1531]=00bf0025002456e0
        [530]=18b100244ff0000b4d [1530]=002000244ff0000b57
        [529]=44387810b1002400254a [1529]=44387800200024002556
        [629]=90387810b1002400254a [1629]=90387800200024002558
    )

    local HEXDATA
    HEXDATA="$(xxd -p -c 0 "$BT_LIB_FILE")" || return 1

    local PATCHED=0

    for idx in "${!hex[@]}"; do
        (( idx >= 1000 )) && continue

        local from="${hex[$idx]}"
        local to="${hex[$((idx + 1000))]}"

        [ -z "$to" ] && continue

        # convert wildcard .... → regex
        local from_regex="${from//./[0-9a-f]}"

        if echo "$HEXDATA" | grep -qiE "$from_regex"; then
            echo "- Found Bluetooth patch pattern [$idx]"
            HEX_PATCH "$BT_LIB_FILE" "$from" "$to" || return 1
            PATCHED=1
			cp -rfa "$WORK_DIR/libbluetooth_jni.so" "$EXTRACTED_FIRM_DIR/system/system/lib64/"
            break
        fi
    done

    if [ "$PATCHED" -eq 0 ]; then
        echo "- No known Bluetooth patch pattern matched."
		rm -rf "$BT_LIB_FILE"
        return 1
    fi

    return 0
}


FIX_VNDK() {
    echo "- Checking $STOCK_DEVICE and $TARGET_DEVICE vndk version."
    if [ -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" ]; then
        echo "- VNDK matched."
    else
        echo "- VNDK mismatch or missing."
        rm -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk"*.apex
        cp -rfa "$VNDKS_COLLECTION/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" "$TARGET_ROM_SYSTEM_EXT_DIR/apex/"
        sed -i "/<vendor-ndk>/,/<\/vendor-ndk>/ s|<version>[0-9]\+</version>|<version>${STOCK_VNDK_VERSION}</version>|" "$TARGET_ROM_SYSTEM_EXT_DIR/etc/vintf/manifest.xml"
    fi
}


FIX_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

	if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "TRUE" ] && [ -d "$EXTRACTED_FIRM_DIR/system_ext" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system_ext"
		return 1
	fi

    if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "FALSE" ] && [[ -d "$EXTRACTED_FIRM_DIR/system_ext" ]]; then
        echo "- Copying system_ext content into system root"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
        cp -a --preserve=all "$EXTRACTED_FIRM_DIR/system_ext" "$EXTRACTED_FIRM_DIR/system"

        echo "- Cleaning and merging system_ext file contexts and configs"
        # File paths
        SYSTEM_EXT_CONFIG_FILE="$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
        SYSTEM_EXT_CONTEXTS_FILE="$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"

        SYSTEM_CONFIG_FILE="$EXTRACTED_FIRM_DIR/config/system_fs_config"
        SYSTEM_CONTEXTS_FILE="$EXTRACTED_FIRM_DIR/config/system_file_contexts"

        SYSTEM_EXT_TEMP_CONFIG="${SYSTEM_EXT_CONFIG_FILE}.tmp"
        SYSTEM_EXT_TEMP_CONTEXTS="${SYSTEM_EXT_CONTEXTS_FILE}.tmp"

        # Clean system_ext contexts
        grep -v '^/ u:object_r:system_file:s0$' "$SYSTEM_EXT_CONTEXTS_FILE" \
        | grep -v '^/system_ext u:object_r:system_file:s0$' \
        | grep -v '^/system_ext(.*)? u:object_r:system_file:s0$' \
        | grep -v '^/system_ext/ u:object_r:system_file:s0$' \
        > "$SYSTEM_EXT_TEMP_CONTEXTS" && mv "$SYSTEM_EXT_TEMP_CONTEXTS" "$SYSTEM_EXT_CONTEXTS_FILE"

        # Clean system_ext config
        grep -v '^/ 0 0 0755$' "$SYSTEM_EXT_CONFIG_FILE" \
        | grep -v '^system_ext/ 0 0 0755$' \
        | grep -v '^system_ext/lost+found 0 0 0755$' \
        > "$SYSTEM_EXT_TEMP_CONFIG" && mv "$SYSTEM_EXT_TEMP_CONFIG" "$SYSTEM_EXT_CONFIG_FILE"

        # Fix system_ext config
        awk '{print "system/" $0}' "$SYSTEM_EXT_CONFIG_FILE" \
        > "$SYSTEM_EXT_TEMP_CONFIG" && mv "$SYSTEM_EXT_TEMP_CONFIG" "$SYSTEM_EXT_CONFIG_FILE"

        # Fix system_ext contexts
        awk '{print "/system" $0}' "$SYSTEM_EXT_CONTEXTS_FILE" \
        > "$SYSTEM_EXT_TEMP_CONTEXTS" && mv "$SYSTEM_EXT_TEMP_CONTEXTS" "$SYSTEM_EXT_CONTEXTS_FILE"

        # Append cleaned system_ext config into system config
        cat "$SYSTEM_EXT_CONFIG_FILE" >> "$SYSTEM_CONFIG_FILE"

        # Append cleaned system_ext contexts into system contexts
        cat "$SYSTEM_EXT_CONTEXTS_FILE" >> "$SYSTEM_CONTEXTS_FILE"

		export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"

	    rm -rf "$EXTRACTED_FIRM_DIR/system_ext"
		rm -rf "$EXTRACTED_FIRM_DIR/config/system_ext_fs_config"
		rm -rf "$EXTRACTED_FIRM_DIR/config/system_ext_file_contexts"
    else
	    export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
    fi
}


FIX_SELINUX() {
    echo ""
    local SELINUX_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/mapping/${STOCK_VNDK_VERSION}.0.cil"

    if [ ! -f "$SELINUX_FILE" ]; then
        echo "Error: SELinux file not found at $SELINUX_FILE"
        return 1
    fi

    echo "Fixing selinux for $STOCK_DEVICE."

    UNSUPPORTED_SELINUX=("audiomirroring" "fabriccrypto" "hal_dsms_default" "qb_id_prop" "hal_dsms_service" "proc_compaction_proactiveness" "sbauth" "ker_app" "kpp_app" "kpp_data" "attiqi_app" "kpoc_charger")

    for keyword in "${UNSUPPORTED_SELINUX[@]}"; do
        if grep -q "$keyword" "$SELINUX_FILE"; then
            sed -i "/$keyword/d" "$SELINUX_FILE"
        fi
    done

	REMOVE_LINE '(genfscon proc "/sys/kernel/firmware_config" (u object_r proc_fmw ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil"
	REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil"
    REMOVE_LINE 'init.svc.vendor.wvkprov_server_hal                           u:object_r:wvkprov_prop:s0' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_property_contexts"
}


UPDATE_FLOATING_FEATURE() {
    local key="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo "⛔️️ Skipping $key — no value found."
        return
    fi

    if grep -q "<${key}>.*</${key}>" "$TARGET_FLOATING_FEATURE"; then
        local current_line
        current_line=$(grep "<${key}>.*</${key}>" "$TARGET_FLOATING_FEATURE")
        local current_value
        current_value=$(echo "$current_line" | sed -E "s/.*<${key}>(.*)<\/${key}>.*/\1/")

        if [[ "$current_value" == "$value" ]]; then
            return
        fi

        local indent
        indent=$(echo "$current_line" | sed -E "s/(<${key}>.*<\/${key}>).*//")
        local line="${indent}<${key}>${value}</${key}>"
        sed -i "s|${indent}<${key}>.*</${key}>|$line|" "$TARGET_FLOATING_FEATURE"
        echo "✳️ Updated $key with ▶️ $value"
    else
        local line="    <$key>$value</$key>"
        sed -i "3i\\$line" "$TARGET_FLOATING_FEATURE"
        echo "✅️ Added $key with value ▶️ $value"
    fi
}


APPLY_CUSTOM_FLOATING_FEATURE() {
    echo ""
	echo "============ Applying Custom Floating Feature ============"
    #========== COMMON ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_SEP_CATEGORY" "sep_basic"

    #============= AI ==========#
    sed -i '/SEC_FLOATING_FEATURE_COMMON_DISABLE_NATIVE_AI/d' "$TARGET_FLOATING_FEATURE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_VISION_SUPPORT_AI_MY_FAVORITE_CONTENTS" "TRUE"

    #========== EDGE ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_EDGE" "panel"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEMUI_SUPPORT_BRIEF_NOTIFICATION" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEMUI_CONFIG_EDGELIGHTING_FRAME_EFFECT" "frame_effect"

    #========== SCREEN RECORDER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_SCREEN_RECORDER" "TRUE"
	
	#========== VOICE RECORDER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_VOICERECORDER_CONFIG_DEF_MODE" "normal,interview,voicememo"

    #========== AUDIO ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_BT_RECORDING" "TRUE"

    #========== BATTERY ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_GALAXYDIAGNOSTICS" "TRUE"

    #========== SETTINGS ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_DEFAULT_DOUBLE_TAP_TO_WAKE" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_FUNCTION_KEY_MENU" "TRUE"

    #========== SYSTEM ============#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_CPU_RESPONSIVENESS" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_PROCESSING" "TRUE"

    #========== LAUNCHER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LAUNCHER_SUPPORT_CLOCK_LIVE_ICON" "TRUE"

    #========== AOD ==========#
	if [ -d "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app"/AODService_* ]; then
	    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_AOD_ITEM" "aodversion=7,clocktransition,coverboldfont"
        UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_AOD_FULLSCREEN" "1"
    fi

    #========== CAMERA ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_STRIDE_OCR_VERSION" "V1"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_PRIVACY_TOGGLE" "TRUE"

    #========== GENAI ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_IMAGE_CLIPPER" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_OBJECT_ERASER" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_REFLECTION_ERASER" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SHADOW_ERASER" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SMART_LASSO" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SPOT_FIXER" "TRUE"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_GENAI_SUPPORT_STYLE_TRANSFER" "TRUE"
}


APPLY_STOCK_FLOATING_FEATURE() {
    echo " "
    echo "============ Applying Stock Floating Feature ============"
    #========== AUDIO ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_STAGE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_STAGE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_VOLUME_MONITOR" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_VOLUME_MONITOR" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_REMOTE_MIC" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_REMOTE_MIC" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_GAIN" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_GAIN" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== SETTINGS ==========#
	UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_ELECTRIC_RATED_VALUE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_ELECTRIC_RATED_VALUE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_DEFAULT_FONT_SIZE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_DEFAULT_FONT_SIZE" {print $3}' "$STOCK_FLOATING_FEATURE")"

	#========== REFRESH RATE ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== SYSTEM ==========#
	UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_FLOATING_FEATURE")"
	UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE")"

	#========== LAUNCHER ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== DISPLAY ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_CONFIG_DEFAULT_SCREEN_MODE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_CONFIG_DEFAULT_SCREEN_MODE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_SUPPORT_NATURAL_SCREEN_MODE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_SUPPORT_NATURAL_SCREEN_MODE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LCD_SUPPORT_SCREEN_MODE_TYPE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LCD_SUPPORT_SCREEN_MODE_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== CAMERA ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_BINNING" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_BINNING" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_MEMORY_USAGE_LEVEL" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_MEMORY_USAGE_LEVEL" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_QRCODE_INTERVAL" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_QRCODE_INTERVAL" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_UW_DISTORTION_CORRECTION" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_UW_DISTORTION_CORRECTION" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_AVATAR_MAX_FACE_NUM" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_AVATAR_MAX_FACE_NUM" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_STANDARD_CROP" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_STANDARD_CROP" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_HIGH_RESOLUTION_MAX_CAPTURE" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_HIGH_RESOLUTION_MAX_CAPTURE" {print $3}' "$STOCK_FLOATING_FEATURE")"
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_NIGHT_FRONT_DISPLAY_FLASH_TRANSPARENT" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_CAMERA_CONFIG_NIGHT_FRONT_DISPLAY_FLASH_TRANSPARENT" {print $3}' "$STOCK_FLOATING_FEATURE")"

	#========== BIOAUTH ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_BIOAUTH_CONFIG_FINGERPRINT_FEATURES" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_BIOAUTH_CONFIG_FINGERPRINT_FEATURES" {print $3}' "$STOCK_FLOATING_FEATURE")"

    #========== LOCKSCREEN ==========#
    UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_PUNCHHOLE_VI" "$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_PUNCHHOLE_VI" {print $3}' "$STOCK_FLOATING_FEATURE")"
}


REMOVE_ESIM_FILES() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
    echo "- Removing ESIM files."
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
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
    echo "- Removing fabric crypto."
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


APPLY_STOCK_CONFIG() {
    echo ""
	if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        echo "No target device is set. Just modifying ROM without any device config."
        return 1
    fi

	echo "Applying $STOCK_DEVICE device config."
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ ! -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo "- Config file for $STOCK_DEVICE not found in $DEVICES_DIR"
        return 1
	fi

    if [ -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo "- $STOCK_DEVICE config found."
        export STOCK_VNDK_VERSION="$(grep -m1 '^STOCK_VNDK_VERSION=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
        export STOCK_HAS_SEPARATE_SYSTEM_EXT="$(grep -m1 '^STOCK_HAS_SEPARATE_SYSTEM_EXT=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export STOCK_DVFS_FILENAME="$(grep -m1 '^STOCK_DVFS_FILENAME=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    fi

    export STOCK_FLOATING_FEATURE="$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml"
	export STOCK_SIOP_FILENAME="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_FLOATING_FEATURE" | tr -d '\r' | xargs)"

	# FIX SYSTEM_EXT.
    FIX_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"

	# FIX VNDK.
	FIX_VNDK

	# FIX SELINUX.
	FIX_SELINUX

    # STOCK STOCK FLOATING FEATURES
	APPLY_STOCK_FLOATING_FEATURE

	# Replace Stock Files.
	find "$EXTRACTED_FIRM_DIR/system/system/media" -maxdepth 1 -type f \( -iname "*.spi" -o -iname "*.qmg" -o -iname "*.txt" \) -delete
	rm -rf $EXTRACTED_FIRM_DIR/product/overlay/framework-res*auto_generated_rro_product.apk
	cp -a "$DEVICES_DIR/$STOCK_DEVICE/Stock/." "$EXTRACTED_FIRM_DIR/"
}


DEBLOAT_APPS=("FactoryCameraFB" "WlanTest" "AssistantShell" "HotwordEnrollmentOKGoogleEx4CORTEXM55" "HotwordEnrollmentXGoogleEx4CORTEXM55" "BardShell" "DuoStub" "GoogleCalendarSyncAdapter" "AndroidDeveloperVerifier" "AndroidGlassesCore" "SOAgent77" "YourPhone_Stub" "AndroidAutoStub" "SingleTakeService" "SamsungBilling" "AndroidSystemIntelligence" "GoogleRestore" "Messages" "SearchSelector" "AirGlance" "AirReadingGlass" "SamsungTTS" "WlanTest" "ARCore" "ARDrawing" "ARZone" "BGMProvider" "BixbyWakeup" "BlockchainBasicKit" "Cameralyzer" "DictDiotekForSec" "EasymodeContactsWidget81" "Fast" "FBAppManager_NS" "FunModeSDK" "GearManagerStub" "KidsHome_Installer" "LinkSharing_v11" "LiveDrawing" "MAPSAgent" "MdecService" "MinusOnePage" "MoccaMobile" "Netflix_stub" "Notes40" "ParentalCare" "PhotoTable" "PlayAutoInstallConfig" "SamsungPassAutofill_v1" "SamsungTTSVoice_de_DE_f00" "SamsungTTSVoice_el_GR_f00" "SamsungTTSVoice_en_GB_f00" "SamsungTTSVoice_en_US_f00" "SamsungTTSVoice_en_US_l03" "SamsungTTSVoice_es_ES_f00" "SamsungTTSVoice_es_MX_f00" "SamsungTTSVoice_es_US_f00" "SamsungTTSVoice_fr_FR_f00" "SamsungTTSVoice_hi_IN_f00" "SamsungTTSVoice_it_IT_f00" "SamsungTTSVoice_pl_PL_f00" "SamsungTTSVoice_pt_BR_f00" "SamsungTTSVoice_ru_RU_f00" "SamsungTTSVoice_th_TH_f00" "SamsungTTSVoice_vi_VN_f00" "SamsungTTSVoice_en_IN_f00" "SmartReminder" "SmartSwitchStub" "UnifiedWFC" "UniversalMDMClient" "VideoEditorLite_Dream_N" "VisionIntelligence3.7" "VoiceAccess" "VTCameraSetting" "WebManual" "WifiGuider" "KTAuth" "KTCustomerService" "KTUsimManager" "LGUMiniCustomerCenter" "LGUplusTsmProxy" "SamsungTTSVoice_ko_KR_r00" "SketchBook" "SKTMemberShip_new" "SktUsimService" "TWorld" "AirCommand" "AppUpdateCenter" "AREmoji" "AREmojiEditor" "AuthFramework" "AutoDoodle" "AvatarEmojiSticker" "AvatarEmojiSticker_S" "Bixby" "BixbyInterpreter" "BixbyVisionFramework3.5" "DevGPUDriver-EX2200" "DigitalKey" "Discover" "DiscoverSEP" "EarphoneTypeC" "EasySetup" "FBInstaller_NS" "FBServices" "FotaAgent" "GalleryWidget" "GameDriver-EX2100" "GameDriver-EX2200" "GameDriver-SM8150" "HashTagService" "MultiControlVP6" "LedCoverService" "LinkToWindowsService" "LiveStickers" "MemorySaver_O_Refresh" "MultiControl" "OMCAgent5" "OneDrive_Samsung_v3" "OneStoreService" "SamsungCarKeyFw" "SamsungPass" "SamsungSmartSuggestions" "SettingsBixby" "SetupIndiaServicesTnC" "SKTFindLostPhone" "SKTHiddenMenu" "SKTMemberShip" "SKTOneStore" "SktUsimService" "SmartEye" "SmartPush" "SmartThingsKit" "SmartTouchCall" "SOAgent7" "SOAgent75" "SolarAudio-service" "SPPPushClient" "sticker" "StickerFaceARAvatar" "StoryService" "SumeNNService" "SVoiceIME" "SwiftkeyIme" "SwiftkeySetting" "SystemUpdate" "TADownloader" "TalkbackSE" "TaPackAuthFw" "TPhoneOnePackage" "TPhoneSetup" "TWorld" "UltraDataSaving_O" "Upday" "UsimRegistrationKOR" "YourPhone_P1_5" "AvatarPicker" "GpuWatchApp" "KT114Provider2" "KTHiddenMenu" "KTOneStore" "KTServiceAgent" "KTServiceMenu" "LGUGPSnWPS" "LGUHiddenMenu" "LGUOZStore" "SKTFindLostPhoneApp" "SmartPush_64" "SOAgent76" "TService" "vexfwk_service" "VexScanner" "LiveEffectService" "YourPhone_P1_5" "vexfwk_service")

KICK() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi
    
	local EXTRACTED_FIRM_DIR="$1"

    echo "- Debloating apps."
    local APP_DIRS=(
        "$EXTRACTED_FIRM_DIR/system/system/app"
        "$EXTRACTED_FIRM_DIR/system/system/priv-app"
        "$EXTRACTED_FIRM_DIR/product/app"
        "$EXTRACTED_FIRM_DIR/product/priv-app"
    )

    for app in "${DEBLOAT_APPS[@]}"; do
        for dir in "${APP_DIRS[@]}"; do
            target="$dir/$app"

            if [[ -d "$target" ]]; then
                rm -rf "$target" || echo "[WARN] Failed to remove $target"
            fi
        done
    done
}


DEBLOAT() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
    echo "Debloating."
    KICK "$EXTRACTED_FIRM_DIR"
    REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
	REMOVE_FABRIC_CRYPTO "$EXTRACTED_FIRM_DIR"
	echo "- Deleting unnecessary files and folders."
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.bprof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init/boot-image.prof"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/hidden"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/preload"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/tts"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/mediasearch"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/MediaSearch"
}


BUILD_PROP() {
    local EXTRACTED_FIRM_DIR="$1"
    local KEY="$2"
    local VALUE="${3:-}"

    if [ -z "$EXTRACTED_FIRM_DIR" ] || [ -z "$KEY" ]; then
        echo "Usage: BUILD_PROP <EXTRACTED_FIRM_DIR> <key> [value]"
        return 1
    fi

    local PROP_FILES=(
        "$EXTRACTED_FIRM_DIR/product/etc/build.prop"
        "$EXTRACTED_FIRM_DIR/system/system/build.prop"
    )
    for PROP in "${PROP_FILES[@]}"; do
        [ -f "$PROP" ] || continue

        if [ -z "$VALUE" ]; then
            sed -i "/^${KEY}=.*/d" "$PROP"
            echo " Removed: $KEY"
        else
            if grep -q "^${KEY}=" "$PROP"; then
                sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$PROP"
                echo " Updated: $KEY=$VALUE"
            else
                echo "${KEY}=${VALUE}" >> "$PROP"
                echo " Added: $KEY=$VALUE"
            fi
        fi
    done
}


APPLY_CUSTOM_FEATURES() {
    echo ""
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    echo "Applying usefull features."
	echo " Adding build prop tweak."
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.frp.pst"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.product.locale" "en-US"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "fw.max_users" "5"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "fw.show_multiuserui" "1"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "wifi.interface=" "wlan0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "wlan.wfd.hdcp" "disabled"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "debug.hwui.renderer" "skiavk"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.telephony.sim_slots.count" "2"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "ro.surface_flinger.protected_contents" "true"

	echo " Adding China smart manager."
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/AppLock"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/Firewall"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SmartManager_v5"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SmartManagerCN"
	cp -rfa "$(pwd)/QuantumROM/Mods/SMART_MANAGER_CN/." "$EXTRACTED_FIRM_DIR/"
	UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SMARTMANAGER_CONFIG_PACKAGE_NAME" "com.samsung.android.sm_cn"

	echo "Adding full OneUI and important apps."
    if [ -d "$EXTRACTED_FIRM_DIR/system/system/app/ClockPackage" ]; then
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/system/system/app/ClockPackage" "$EXTRACTED_FIRM_DIR/system/system/app/"
    fi

	if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull" ]; then
	    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/PhotoEditor_*
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/system/system/priv-app/PhotoEditor_AIFull" "$EXTRACTED_FIRM_DIR/system/system/priv-app/"
    fi

    # STOCK CUSTOM FLOATING FEATURES
	APPLY_CUSTOM_FLOATING_FEATURE

	# Remove power and data usage permissions for certain apps when Power Saver and Data Saver are always enabled.
	# sed -i '/^[[:space:]]*<allow-in-power-save/d; /^[[:space:]]*<allow-in-data-usage-save/d' "$EXTRACTED_FIRM_DIR/product/etc/sysconfig/"*.xml "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/"*.xml
}


GEN_FS_CONFIG() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    [ ! -d "$EXTRACTED_FIRM_DIR" ] && {
        echo "- $EXTRACTED_FIRM_DIR not found."
        return 1
    }

    [ ! -d "$EXTRACTED_FIRM_DIR/config" ] && {
        echo "[ERROR] config directory missing"
        return 1
    }

    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [ ! -d "$ROOT" ] && continue

        PARTITION="$(basename "$ROOT")"
        [ "$PARTITION" = "config" ] && continue

        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        local TMP_EXISTING
        TMP_EXISTING="$(mktemp)"

        touch "$FS_CONFIG"

        echo ""
        echo "Generating fs_config for partition: $PARTITION"
        #echo "- Source : $ROOT"
        #echo "- Output : $FS_CONFIG"

        awk '{print $1}' "$FS_CONFIG" | sort -u > "$TMP_EXISTING"

        find "$ROOT" -mindepth 1 \( -type f -o -type d \) | while IFS= read -r item; do
            local REL_PATH="${item#$ROOT/}"
            local PATH_ENTRY="$PARTITION/$REL_PATH"

            grep -qxF "$PATH_ENTRY" "$TMP_EXISTING" && continue

            if [ -d "$item" ]; then
                # echo "- Dir  : $PATH_ENTRY (0755)"
                printf "%s 0 0 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            else
                # echo "- File : $PATH_ENTRY (0644)"
                printf "%s 0 0 0644\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            fi
        done

        rm -f "$TMP_EXISTING"
        echo "- $PARTITION fs_config generated"
    done
}


GEN_FILE_CONTEXTS() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    [ ! -d "$EXTRACTED_FIRM_DIR" ] && { echo "- $EXTRACTED_FIRM_DIR not found."; return 1; }
    [ ! -d "$EXTRACTED_FIRM_DIR/config" ] && { echo "[ERROR] config directory missing"; return 1; }

    for ROOT in "$EXTRACTED_FIRM_DIR"/*; do
        [ ! -d "$ROOT" ] && continue
        PARTITION="$(basename "$ROOT")"
        [ "$PARTITION" = "config" ] && continue

        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        touch "$FILE_CONTEXTS"

        echo ""
        echo "Generating file_contexts for partition: $PARTITION"

        declare -A EXISTING=()
        while IFS= read -r line; do
            [ -z "$line" ] && continue
            PATH_ONLY=$(echo "$line" | awk '{print $1}')
            EXISTING["$PATH_ONLY"]=1
        done < "$FILE_CONTEXTS"

        find "$ROOT" -mindepth 1 \( -type f -o -type d \) | while IFS= read -r item; do
            local REL_PATH="${item#$ROOT}"
            local PATH_ENTRY="/$PARTITION$REL_PATH"

            local ESCAPED_PATH
            ESCAPED_PATH=$(echo "$PATH_ENTRY" | sed -e 's/[.+]/\\&/g')

            [ "${EXISTING[$ESCAPED_PATH]+exists}" ] && continue

            printf "%s u:object_r:system_file:s0\n" "$ESCAPED_PATH" >> "$FILE_CONTEXTS"

            EXISTING["$ESCAPED_PATH"]=1
        done

        echo "- $PARTITION file_contexts generated"
        unset EXISTING
    done
}


BUILD_IMG() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <FILE_SYSTEM> <OUT_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local FILE_SYSTEM="$2"
	local OUT_DIR="$3"

    GEN_FS_CONFIG "$EXTRACTED_FIRM_DIR"
	GEN_FILE_CONTEXTS "$EXTRACTED_FIRM_DIR"

    for PART in "$EXTRACTED_FIRM_DIR"/*; do
        [[ -d "$PART" ]] || continue    
        PARTITION="$(basename "$PART")"
        [[ "$PARTITION" == "config" ]] && continue 

        local SRC_DIR="$EXTRACTED_FIRM_DIR/$PARTITION"
        local OUT_IMG="$OUT_DIR/${PARTITION}.img"
        local FS_CONFIG="$EXTRACTED_FIRM_DIR/config/${PARTITION}_fs_config"
        local FILE_CONTEXTS="$EXTRACTED_FIRM_DIR/config/${PARTITION}_file_contexts"
        local SIZE=$(du -sb --apparent-size "$SRC_DIR" | awk '{printf "%.0f", $1 * 1.2}')
		MOUNT_POINT="/$PARTITION"

        echo ""
        [[ -f "$FS_CONFIG" ]] || { echo "Warning: $FS_CONFIG missing, skipping $PARTITION"; continue; }
        [[ -f "$FILE_CONTEXTS" ]] || { echo "Warning: $FILE_CONTEXTS missing, skipping $PARTITION"; continue; }

        sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"
        sort -u "$FS_CONFIG" -o "$FS_CONFIG"

        if [[ "$FILE_SYSTEM" == "erofs" ]]; then
            echo -e "\e[33mBuilding EROFS image:\e[0m $OUT_IMG"
            $(pwd)/bin/erofs-utils/mkfs.erofs --mount-point="$MOUNT_POINT" --fs-config-file="$FS_CONFIG" --file-contexts="$FILE_CONTEXTS" -z lz4hc -b 4096 -T 1199145600 "$OUT_IMG" "$SRC_DIR" >/dev/null 2>&1

        elif [[ "$FILE_SYSTEM" == "ext4" ]]; then
            echo -e "\e[33mBuilding ext4 image:\e[0m $OUT_IMG"
            $(pwd)/bin/ext4/make_ext4fs -l "$(awk "BEGIN {printf \"%.0f\", $SIZE * 1.1}")" -J -b 4096 -S "$FILE_CONTEXTS" -C "$FS_CONFIG"  -a "$MOUNT_POINT" -L "$PARTITION" "$OUT_IMG" "$SRC_DIR"
			# Resize img to reduce size.
			resize2fs -M "$OUT_IMG"
        else
            echo "Unknown filesystem: $FILE_SYSTEM, skipping $PARTITION"
            continue
        fi
    done
}
