#!/bin/bash

###################################################################################################

REAL_USER=${SUDO_USER:-$USER}

# QT DIR
QT_DIR="$(pwd)"

# Binary
export lpmake="$QT_DIR/bin/lp/lpmake"
export lpunpack="$QT_DIR/bin/lp/lpunpack"
export make_ext4fs="$QT_DIR/bin/ext4/make_ext4fs"
export make_f2fs="$QT_DIR/bin/f2fs-tools/mkfs.f2fs"
export sload_f2fs="$QT_DIR/bin/f2fs-tools/sload.f2fs"
export omc_decoder="$QT_DIR/bin/java/omc-decoder.jar"
export mkfs_erofs="$QT_DIR/bin/erofs-utils/mkfs.erofs"
export extract_erofs="$QT_DIR/bin/erofs-utils/extract.erofs"
export imgextractor_py="$QT_DIR/bin/py_scripts/imgextractor.py"

chmod +x "$lpmake"
chmod +x "$lpunpack"
chmod +x "$make_f2fs"
chmod +x "$sload_f2fs"
chmod +x "$mkfs_erofs"
chmod +x "$make_ext4fs"
chmod +x "$extract_erofs"

CHECK_FILE() {
    if [ ! -f "$1" ]; then
        echo -e "[!] File not found: $1"
        echo -e "- Skipping..."
        return 1
    fi
    return 0
}


REMOVE_LINE() {
    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <TARGET_LINE> <TARGET_FILE>"
        return 1
    fi

    local LINE="$1"
    local FILE="$2"

    echo -e "- Deleting $LINE from $FILE"
    grep -vxF "$LINE" "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
}


GET_PROP() {
    if [ "$#" -ne 3 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <PARTITION> <PROP>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"
    local PROP="$3"

    case "$PARTITION" in
        system)
            FILE="$EXTRACTED_FIRM_DIR/system/system/build.prop"
            ;;
        vendor)
            FILE="$EXTRACTED_FIRM_DIR/vendor/build.prop"
            ;;
        product)
            FILE="$EXTRACTED_FIRM_DIR/product/etc/build.prop"
            ;;
        system_ext)
            FILE="$EXTRACTED_FIRM_DIR/system_ext/etc/build.prop"
            ;;
        odm)
            FILE="$EXTRACTED_FIRM_DIR/odm/etc/build.prop"
            ;;
        *)
            echo -e "Unknown partition: $PARTITION"
            return 1
            ;;
    esac

    if [ ! -f "$FILE" ]; then
        echo -e "$FILE not found."
        return 1
    fi

    local VALUE
    VALUE=$(grep -m1 "^${PROP}=" "$FILE" | cut -d'=' -f2-)

    if [ -z "$VALUE" ]; then
        return 1
    fi

    echo -e "$VALUE"
}


DETECT_FILESYSTEM() {
    local imgfile="$1"

    [ ! -f "$imgfile" ] && {
        echo "unknown"
        return 1
    }

    local fstype=$(blkid -o value -s TYPE "$imgfile" 2>/dev/null)
    [ -z "$fstype" ] && fstype=$(file -b "$imgfile" 2>/dev/null)

    case "$fstype" in
        *"Android sparse image"*)
            echo "sparse"
            ;;
        *"ext2"*)
            echo "ext2"
            ;;
        *"ext3"*)
            echo "ext3"
            ;;
        *"ext4"*)
            echo "ext4"
            ;;
        *"f2fs"*|*"F2FS"*)
            echo "f2fs"
            ;;
        *"erofs"*|*"EROFS"*)
            echo "erofs"
            ;;
        *"squashfs"*|*"Squashfs"*)
            echo "squashfs"
            ;;
        *"LZ4 compressed"*)
            echo "lz4"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}


DOWNLOAD_FIRMWARE() {
    echo " "

    if [ "$#" -lt 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <MODEL> <CSC> <IMEI> <DOWNLOAD_DIRECTORY> [VERSION]"
        return 1
    fi

    local MODEL="$1"
    local CSC="$2"
    local IMEI="$3"
    local DOWN_DIR="${4}/$MODEL"
    local VERSION="${5:-}"

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo -e "======================================"
    echo -e "${YELLOW}  Samsung FW Downloader   ${NC}"
    echo -e "======================================"
    echo -e "MODEL: $MODEL | CSC: $CSC"

    # --- Step 1: Determine Version ---
    if [ -n "$VERSION" ]; then
        echo -e "✅ Downloading provided version: $VERSION"
    fi

    VERSION=$(python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" checkupdate 2>&1)

    if [ $? -ne 0 ] || [ -z "$VERSION" ]; then
        echo -e "⛔️ MODEL/CSC/IMEI not valid or no update found."
        echo -e "Error: $VERSION"
        return 1
    fi

    if [ -n "$GITHUB_ENV" ]; then
        echo "VERSION=$VERSION" >> "$GITHUB_ENV"
    fi

    # --- Step 2: Download Firmware ---
    python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" download -v "$VERSION" -O "$DOWN_DIR"
    if [ $? -ne 0 ]; then
        echo -e "⛔️ Download failed. Check IMEI/MODEL/CSC."
        exit 1
    fi

	find "$DOWN_DIR" -type f -name "*.zip.enc*" -delete

    # --- Show Firmware Info ---
    local file_size=$(du -m "${DOWN_DIR}"/${MODEL}_*_fac.zip 2>/dev/null | cut -f1)
    echo -e "Firmware Size: ${file_size} MB"
}


EXTRACT_FIRMWARE() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"

    echo -e "Extracting downloaded firmware."

	if [ ! -d "$FIRM_DIR" ]; then
        echo -e "- Directory not found: $FIRM_DIR"
        exit
    fi

    # ---- ZIP ----
    for file in "$FIRM_DIR"/*.zip; do
        [ -e "$file" ] || continue

        echo -e "Extracting zip: $(basename "$file")"
        7z x -y -bd -bsp1 -o"$FIRM_DIR" "$file"

        rm -f "$file"
    done

    # remove unwanted archives before extraction
    rm -f "$FIRM_DIR"/BL_*.tar.md5
    rm -f "$FIRM_DIR"/CP_*.tar.md5
    rm -f "$FIRM_DIR"/HOME_CSC_*.tar.md5
	rm -f "$FIRM_DIR"/USERDATA_*.tar.md5

    # ---- XZ ----
    for file in "$FIRM_DIR"/*.xz; do
        [ -e "$file" ] || continue

        echo -e "Extracting xz: $(basename "$file")"
        7z x -y -bd -bsp1 -o"$FIRM_DIR" "$file"

        rm -f "$file"
    done

    # ---- RENAME .MD5 -> .TAR ----
    for file in "$FIRM_DIR"/*.md5; do
        [ -e "$file" ] || continue

        mv -- "$file" "${file%.md5}"
    done

    # ---- TAR ----
    for file in "$FIRM_DIR"/*.tar; do
        [ -e "$file" ] || continue

        echo -e "Extracting tar: $(basename "$file")"

        tar -xf "$file" -C "$FIRM_DIR"

        # remove only samsung firmware tar archives
        case "$(basename "$file")" in
            AP_*|BL_*|CP_*|CSC_*|HOME_CSC_*)
                rm -f "$file"
                ;;
        esac
    done

    # ---- REMOVE UNWANTED LZ4 FILES ----
    rm -rf \
        "$FIRM_DIR/meta-data" \
        "$FIRM_DIR"/*.txt \
        "$FIRM_DIR"/*.pit \
        "$FIRM_DIR"/*.bin \
        "$FIRM_DIR"/cache.img.lz4 \
        "$FIRM_DIR"/dtbo.img.lz4 \
        "$FIRM_DIR"/efuse.img.lz4 \
        "$FIRM_DIR"/gz-verified.img.lz4 \
        "$FIRM_DIR"/lk-verified.img.lz4 \
        "$FIRM_DIR"/md1img.img.lz4 \
        "$FIRM_DIR"/md_udc.img.lz4 \
        "$FIRM_DIR"/misc.bin.lz4 \
        "$FIRM_DIR"/omr.img.lz4 \
        "$FIRM_DIR"/param.bin.lz4 \
        "$FIRM_DIR"/preloader.img.lz4 \
        "$FIRM_DIR"/recovery.img.lz4 \
        "$FIRM_DIR"/scp-verified.img.lz4 \
        "$FIRM_DIR"/spmfw-verified.img.lz4 \
        "$FIRM_DIR"/sspm-verified.img.lz4 \
        "$FIRM_DIR"/tee-verified.img.lz4 \
        "$FIRM_DIR"/tzar.img.lz4 \
        "$FIRM_DIR"/up_param.bin.lz4 \
        "$FIRM_DIR"/userdata.img.lz4 \
        "$FIRM_DIR"/vbmeta.img.lz4 \
        "$FIRM_DIR"/vbmeta_system.img.lz4 \
        "$FIRM_DIR"/audio_dsp-verified.img.lz4 \
        "$FIRM_DIR"/cam_vpu1-verified.img.lz4 \
        "$FIRM_DIR"/cam_vpu2-verified.img.lz4 \
        "$FIRM_DIR"/cam_vpu3-verified.img.lz4 \
        "$FIRM_DIR"/dpm-verified.img.lz4 \
        "$FIRM_DIR"/init_boot.img.lz4 \
        "$FIRM_DIR"/mcupm-verified.img.lz4 \
        "$FIRM_DIR"/pi_img-verified.img.lz4 \
        "$FIRM_DIR"/uh.bin.lz4 \
        "$FIRM_DIR"/vendor_boot.img.lz4 \
        "$FIRM_DIR"/ssu.img.lz4

    # ---- LZ4 ----
    for file in "$FIRM_DIR"/*.lz4; do
        [ -e "$file" ] || continue

        echo -e "Extracting lz4: $(basename "$file")"

        lz4 -d "$file" "${file%.lz4}"

        rm -f "$file"
    done

    echo -e "Firmware Extraction complete."
}


EXTRACT_SUPER_IMG() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FIRMWARE_DIRECTORY>"
        return 1
    fi

    local FIRM_DIR="$1"

    if [ -f "$FIRM_DIR/super.img" ]; then
        echo -e "Extracting super.img"
        if [ "$(DETECT_FILESYSTEM "$FIRM_DIR/super.img")" = "sparse" ]; then
		    echo -e "Converting to raw super.img"
            simg2img "$FIRM_DIR/super.img" "$FIRM_DIR/super_raw.img"
            rm -f "$FIRM_DIR/super.img"
            mv -f "$FIRM_DIR/super_raw.img" "$FIRM_DIR/super.img"
        fi

        echo "- Extracting partitions from super.img"
        "$lpunpack" "$FIRM_DIR/super.img" "$FIRM_DIR" || return 1
        rm -f "$FIRM_DIR/super.img"

        echo -e "super.img extraction complete"

    else
        echo -e "No super.img found."
    fi
}


PREPARE_PARTITIONS() {
	if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        export BUILD_PARTITIONS="odm,product,system_ext,system,vendor,odm_a,product_a,system_ext_a,system_a,vendor_a"
    fi

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    [[ -z "$EXTRACTED_FIRM_DIR" || ! -d "$EXTRACTED_FIRM_DIR" ]] && {
        echo -e "Invalid directory: $EXTRACTED_FIRM_DIR"
        return 1
    }

    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"

    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo -e "${KEEP[$i]}" | xargs)
    done

    echo -e "${YELLOW}Preparing partitinos.${NC} $STOCK_DEVICE"

    find "$EXTRACTED_FIRM_DIR" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

    shopt -s nullglob dotglob

    for item in "$EXTRACTED_FIRM_DIR"/*; do
        base=$(basename "$item")

        [[ "$base" == *.img ]] && base="${base%.img}"

        keep_this=0
        for k in "${KEEP[@]}"; do
            [[ "$k" == "$base" ]] && keep_this=1 && break
        done

        if [[ $keep_this -eq 0 ]]; then
            rm -rf -- "$item"
        fi
    done

    shopt -u nullglob dotglob
}


EXTRACT_FIRMWARE_IMG() {
    echo " "

    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> all|img_name"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local MODE="$2"

    if ! ls "$EXTRACTED_FIRM_DIR"/*.img >/dev/null 2>&1; then
        echo -e "No .img files found in: $EXTRACTED_FIRM_DIR"
        return 1
    fi

    echo -e "Extracting images from: $EXTRACTED_FIRM_DIR"

    extract_img() {
        local imgfile="$1"

        [ -e "$imgfile" ] || return

        local img_name="$(basename "$imgfile")"

        if [[ "$img_name" == "boot.img" || "$img_name" == "recovery.img" ]]; then
            echo -e "- Skipping $img_name"
            return
        fi

        local partition="$(basename "${imgfile%.img}")"
        local ORG_IMG_SIZE=$(stat -c%s -- "$imgfile")

        rm -rf "${EXTRACTED_FIRM_DIR}/$partition"

        local fstype=$(DETECT_FILESYSTEM "$imgfile")
        if [ "$fstype" = "sparse" ]; then
            echo -e "$partition.img is SPARSE. Converting to raw img."

            local tmp_raw="${imgfile}.raw"

            if ! simg2img "$imgfile" "$tmp_raw" >/dev/null 2>&1; then
                echo -e "Failed to convert sparse image: $img_name"
                return
            fi

            if [ ! -f "$tmp_raw" ]; then
                echo -e "- Sparse conversion output missing: $tmp_raw"
                return
            fi

            rm -f "$imgfile"
            mv "$tmp_raw" "$imgfile"
        fi

        local fstype=$(DETECT_FILESYSTEM "$imgfile")

        case "$fstype" in
            ext4)
                echo " "
                echo -e "$partition.img Detected ext4. Size: $ORG_IMG_SIZE bytes. Extracting..."
                python3 "$imgextractor_py" "$imgfile" "$EXTRACTED_FIRM_DIR"
                ;;

            erofs)
                echo " "
                echo -e "$partition.img Detected erofs. Size: $ORG_IMG_SIZE bytes. Extracting..."
                "$extract_erofs" -i "$imgfile" -x -f -o "$EXTRACTED_FIRM_DIR" >/dev/null 2>&1
                ;;

            f2fs)
                echo " "
                echo -e "$partition.img Detected f2fs. Size: $ORG_IMG_SIZE bytes. Extracting..."
                bash "$(pwd)/scripts/extract_img.sh" "$imgfile" "$EXTRACTED_FIRM_DIR"
                ;;

            *)
                echo -e "- $img_name unsupported filesystem type: ($fstype), skipping"
                ;;
        esac
    }

    if [ "$MODE" = "all" ]; then
	    PREPARE_PARTITIONS "$EXTRACTED_FIRM_DIR"
        for imgfile in "$EXTRACTED_FIRM_DIR"/*.img; do
            [ -e "$imgfile" ] || continue
            extract_img "$imgfile"
        done

	    rm -rf "$EXTRACTED_FIRM_DIR"/*.img

    else
        local TARGET_IMG="${EXTRACTED_FIRM_DIR}/$MODE"

        if [ ! -f "$TARGET_IMG" ]; then
            echo -e "- Image not found: $TARGET_IMG"
            return 1
        fi

        extract_img "$TARGET_IMG"
    fi

    chown -R "$REAL_USER:$REAL_USER" "$EXTRACTED_FIRM_DIR"
    chmod -R u+rwX "$EXTRACTED_FIRM_DIR"
}


DISABLE_FBE() {
    local EXTRACTED_FIRM_DIR="$1"

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    if [ ! -d "$EXTRACTED_FIRM_DIR/vendor/etc" ]; then
        echo -e "- $EXTRACTED_FIRM_DIR/vendor/etc directory not found. Skipping FBE disable."
        return 1
    fi

    local fstab_files
    fstab_files=$(grep -lr 'fileencryption' "$EXTRACTED_FIRM_DIR/vendor/etc" 2>/dev/null)

    for i in $fstab_files; do
        if [ -f "$i" ]; then
            echo -e "- Disabling file-based encryption (FBE) for /data."
            echo -e "- Found $i."
            sed -i -e 's/^\([^#].*\)fileencryption=[^,]*\(.*\)$/# &\n\1encryptable\2/g' "$i"
        fi
    done
}


DISABLE_FDE() {
    local EXTRACTED_FIRM_DIR="$1"

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    if [ ! -d "$EXTRACTED_FIRM_DIR/vendor/etc" ]; then
        echo -e "- $EXTRACTED_FIRM_DIR/vendor/etc directory not found. Skipping FDE disable."
        return 1
    fi

    local fstab_files
    fstab_files=$(grep -lr 'forceencrypt' "$EXTRACTED_FIRM_DIR/vendor/etc" 2>/dev/null)

    for i in $fstab_files; do
        if [ -f "$i" ]; then
            echo -e "- Disabling full-disk encryption (FDE) for /data..."
            echo -e "- Found $i."
            md5=$(md5 "$i")
            sed -i -e 's/^\([^#].*\)forceencrypt=[^,]*\(.*\)$/# &\n\1encryptable\2/g' "$i"
            file_changed "$i" "$md5"
        fi
    done
}


INSTALL_FRAMEWORK() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <framework-res.apk>"
        return 1
    fi

    echo -e ""
    local framework_res_apk="$1"
    echo -e "${YELLOW}Installing Framework.${NC}"
    java -jar "$APKTOOL" install-framework "$framework_res_apk"
}


DECOMPILE() {
    echo -e ""
    if [ "$#" -ne 3 ]; then
        echo -e "Usage: DECOMPILE <APKTOOL_JAR_DIR> <FILE> <DECOMPILE_DIR>"
        return 1
    fi

    local APKTOOL="$1"
    local FILE="$2"
    local DECOMPILE_DIR="$3"
    local BASENAME="$(basename "${FILE%.*}")"
    local OUT="$DECOMPILE_DIR/$BASENAME"

    echo -e "${YELLOW}Decompiling:${NC} $FILE"
	rm -rf "$OUT"
    java -jar "$APKTOOL" d -f --match-original "$FILE" -o "$OUT"
}


RECOMPILE() {
    echo -e ""
	if [ "$#" -ne 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <DECOMPILED_DIR> <RECOMPILE_DIR>"
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

    echo -e "${YELLOW}Recompiling:${NC} $DECOMPILED_DIR"
    java -jar "$APKTOOL" b "$DECOMPILED_DIR" --copy-original -p "$FRAMEWORK_DIR" -o "$built_file"

    # Zipalign
	echo -e ""
	if [[ "$ext" == "jar" ]]; then
	    echo -e "${YELLOW}Zipaligning:${NC} $built_file to $final_file"
        zipalign -v 4 "$built_file" "$final_file" >/dev/null 2>&1
		rm -rf "$built_file" "$DECOMPILED_DIR"
    fi
}


REPLACE_SMALI_METHOD() {
    local FILE="$1"
    local METHOD_NAME="$2"
    local NEW_BODY=$(echo -e "$3" | tail -n +2)

    echo -e "- Patching: $FILE"
    echo -e "  Method: $METHOD_NAME"

    if ! grep -Fq "$METHOD_NAME" "$FILE"; then
        echo -e "- ${YELLOW}Method not found → Skipped${NC}"
        return 0
    fi

    # Extract method key (safe match)
    local METHOD_KEY
    METHOD_KEY=$(echo "$METHOD_NAME" | sed -E 's/.* ([^ ]+\().*/\1/')

    sed -i "
/^[[:space:]]*\.method.*$METHOD_KEY/,/^[[:space:]]*\.end method/{
    /^[[:space:]]*\.method/{
        p
        r /dev/stdin
        d
    }
    /^[[:space:]]*\.end method/p
    d
}" "$FILE" <<< "$NEW_BODY"
}


HEX_PATCH() {
    echo -e ""
	if [ "$#" -ne 3 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FILE> <TARGET_VALUE> <REPLACE_VALUE>"
        return 1
    fi

    local FILE="$1"
    local FROM="$(echo -e "$2" | tr '[:upper:]' '[:lower:]')"
    local TO="$(echo -e "$3" | tr '[:upper:]' '[:lower:]')"

    [ ! -f "$FILE" ] && { echo -e "File not found: $FILE"; return 1; }

    xxd -p -c 0 "$FILE" | grep -q "$FROM" || {
        echo -e "- Pattern not found: $FROM"
        return 1
    }

    echo -e "- Patching: $FILE"
    echo -e "- From $FROM to $TO"
    [ -f "$FILE.bak" ] || cp "$FILE" "$FILE.bak"

    xxd -p -c 0 "$FILE" | sed "s/$FROM/$TO/" | xxd -r -p > "$FILE.tmp" &&
    mv "$FILE.tmp" "$FILE"

    xxd -p -c 0 "$FILE" | grep -q "$TO" && {
        echo -e "- Patch success"
        rm -rf "$FILE.bak"        
        return 0
    }

    echo -e "- Patch failed, restoring backup"
    mv "$FILE.bak" "$FILE"
    return 1
}


PATCH_FLAG_SECURE() {
	echo -e ""
	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

	echo -e "${YELLOW}Patching flag secure.${NC}"
    #
	# For android 13
	# local FILE="${1}/smali_classes3/com/android/server/wm/WindowState.smali"
	# local METHOD_NAME_1=".method public isSecureLocked()Z"
	# Only one method.

    # https://github.com/ShaDisNX255/NcX_Stock/commit/c2cc85818df4fe040b4f89ca8f9b78e939b211b4
    # https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-86811691

	local FILE_1="${1}/smali_classes2/com/android/server/wm/WindowState.smali"
    local METHOD_NAME_1=".method public final isSecureLocked()Z"
    local REPLACE_BODY_1='
    .locals 1

    const/4 v0, 0x0

    return v0
    '
    REPLACE_SMALI_METHOD "$FILE_1" "$METHOD_NAME_1" "$REPLACE_BODY_1"
    
	local FILE_2="${1}/smali_classes2/com/android/server/wm/WindowManagerService.smali"
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
    REPLACE_SMALI_METHOD "$FILE_2" "$METHOD_NAME_2" "$REPLACE_BODY_2"
}


PATCH_SECURE_FOLDER() {
    echo -e ""
	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "${YELLOW}Patching secure folder.${NC}"

	#https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-86770885
	local FILE_1="${1}/smali/com/android/server/knox/dar/DarManagerService.smali"
	local METHOD_NAME_1=".method public final checkDeviceIntegrity([Ljava/security/cert/Certificate;)Z"
	local METHOD_NAME_2=".method public final isDeviceRootKeyInstalled()Z"
    local METHOD_NAME_3=".method public final isKnoxKeyInstallable()Z"
    
    local REPLACE_BODY_1='
    .locals 0
 
    const/4 p0, 0x1
 
    return p0
    '

    REPLACE_SMALI_METHOD "$FILE_1" "$METHOD_NAME_1" "$REPLACE_BODY_1"
    REPLACE_SMALI_METHOD "$FILE_1" "$METHOD_NAME_2" "$REPLACE_BODY_1"
	REPLACE_SMALI_METHOD "$FILE_1" "$METHOD_NAME_3" "$REPLACE_BODY_1"

    local FILE_2="${1}/smali/com/android/server/StorageManagerService.smali"
    local METHOD_NAME_4=".method public static isRootedDevice()Z"
    local REPLACE_BODY_2='
    .locals 1
 
    const/4 v0, 0x0
 
    return v0
    '
    REPLACE_SMALI_METHOD "$FILE_2" "$METHOD_NAME_4" "$REPLACE_BODY_2"
}


PATCH_PRIVATE_SHARE() {
    echo -e ""
	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "${YELLOW}Patching private share.${NC}"
	# https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-86805769
	
    local FILE="${1}/smali/com/samsung/android/security/keystore/AttestParameterSpec.smali"
    # patch .method public isVerifiableIntegrity()Z
    local METHOD_NAME=".method public isVerifiableIntegrity()Z"
    local REPLACE_BODY='
    .locals 1
 
    const/4 v0, 0x1
 
    return v0
    '
	REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME" "$REPLACE_BODY"
}


DISABLE_SIGNATURE_VERIFICATION() {
    echo -e ""
	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "${YELLOW}Disabling signature verification.${NC}"
	# https://github.com/ShaDisNX255/NcX_Stock/commit/e9fca1cedf2405c9f84dc2ee4aafa018e59de464
    # https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-87773529
    # https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-87773543

    local FILE="${1}/smali_classes4/android/util/apk/ApkSignatureVerifier.smali"
    # patch .method public static blacklist getMinimumSignatureSchemeVersionForTargetSdk(I)I
    local METHOD_NAME=".method public static blacklist getMinimumSignatureSchemeVersionForTargetSdk(I)I"
    local REPLACE_BODY='
    .locals 1

    const/4 v0, 0x1
 
    return v0
    '
	REPLACE_SMALI_METHOD "$FILE" "$METHOD_NAME" "$REPLACE_BODY"
}


PATCH_KNOX_GUARD() {
    echo -e ""
	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "${YELLOW}Patching knox guard.${NC}"
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
    echo -e ""
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local TARGET_APK="$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"
    local ALT_APK="$(pwd)/QuantumROM/Mods/SDHMS/system/system/priv-app/SamsungDeviceHealthManagerService/SamsungDeviceHealthManagerService.apk"

    if [ -f "$TARGET_APK" ] && zipinfo -1 "$TARGET_APK" 2>/dev/null | grep -q "^res/raw/${STOCK_DVFS_FILENAME}\.xml$"; then
        echo -e "$STOCK_DEVICE Dynamic Voltage and Frequency Scaling table: ${STOCK_DVFS_FILENAME}.xml found in current SDHMS app"
    elif [ -f "$ALT_APK" ] && zipinfo -1 "$ALT_APK" 2>/dev/null | grep -q "^res/raw/${STOCK_DVFS_FILENAME}\.xml$"; then
        echo -e "$STOCK_DEVICE Dynamic Voltage and Frequency Scaling table: ${STOCK_DVFS_FILENAME}.xml found in alternative APK. Replacing in target ROM"
        rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamsungDeviceHealthManagerService"
        cp -a "$(pwd)/QuantumROM/Mods/SDHMS/." "$EXTRACTED_FIRM_DIR/"
    else
        echo -e "$STOCK_DEVICE Dynamic Voltage and Frequency Scaling table: ${STOCK_DVFS_FILENAME}.xml not found anywhere"
    fi
}


PATCH_SSRM() {
    echo -e ""

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SSRM_DIRECTORY>"
        return 1
    fi

    local SSRM_DIR="$1"
    local FILE="$SSRM_DIR/smali/com/android/server/ssrm/Feature.smali"

    echo -e "${YELLOW}Patching ssrm${NC}"
    echo -e "- Patching: $FILE"

    if [ ! -f "$FILE" ]; then
        echo -e "- ${RED}File not found! Skipping...${NC}"
        return 1
    fi

    if grep -Eq 'const-string v[0-9]+, "siop_' "$FILE"; then
        echo -e "- Found siop_ → Replacing"
        sed -i 's/\(const-string v[0-9]\+,\s*"\)siop_[^"]*"/\1'"$STOCK_SIOP_FILENAME"'"/g' "$FILE"
    else
        echo -e "- siop filename not found → Skipped"
    fi

    if grep -Eq 'const-string v[0-9]+, "dvfs_policy_[^"]*_[^"]*"' "$FILE"; then
        echo -e "- Found dvfs_policy_*_* → Replacing"

        sed -i '/dvfs_policy_default/! {
            s/\(const-string v[0-9]\+,\s*"\)dvfs_policy_[^"]*_[^"]*"/\1'"$STOCK_DVFS_FILENAME"'"/g
        }' "$FILE"

    else
        echo -e "- dvfs_policy file name not found → Skipped"
    fi
}


PATCH_BT_LIB() {
    echo -e ""
	if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY> <WORK_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local WORK_DIR="$2"
	local BT_LIB_FILE="$WORK_DIR/libbluetooth_jni.so"

    echo -e "${YELLOW}Patching Bluetooth library.${NC}"
    # Get libbluetooth_jni.so
    unzip "$EXTRACTED_FIRM_DIR/system/system/apex/com.android.btservices.apex" "apex_payload.img" -d "$WORK_DIR" >/dev/null 2>&1
	debugfs -R "dump /lib64/libbluetooth_jni.so $WORK_DIR/libbluetooth_jni.so" "$WORK_DIR/apex_payload.img" >/dev/null 2>&1
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

        if echo -e "$HEXDATA" | grep -qiE "$from_regex"; then
            echo -e "- Found Bluetooth patch pattern [$idx]"
            HEX_PATCH "$BT_LIB_FILE" "$from" "$to" || return 1
            PATCHED=1
			mv -f "$WORK_DIR/libbluetooth_jni.so" "$EXTRACTED_FIRM_DIR/system/system/lib64/"
            break
        fi
    done

    if [ "$PATCHED" -eq 0 ]; then
        echo -e "- No known Bluetooth patch pattern matched."
		rm -rf "$BT_LIB_FILE"
        return 1
    fi

    return 0
}


FIX_VNDK() {
    echo -e "- Checking $STOCK_DEVICE and $TARGET_DEVICE vndk version."
    export SDK="$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" ro.build.version.sdk)"
	echo -e "- Target rom SDK version: $SDK"
    if [ -f "$TARGET_ROM_SYSTEM_EXT_DIR/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" ]; then
        echo -e "- VNDK matched."
    else
        echo -e "- VNDK mismatch. Adding SDK $SDK com.android.vndk.v${STOCK_VNDK_VERSION}.apex"
        rm -rf "$TARGET_ROM_SYSTEM_EXT_DIR/apex/"*.apex
        cp -rfa "$VNDKS_COLLECTION/$SDK/$STOCK_VNDK_VERSION/system_ext/"* "$TARGET_ROM_SYSTEM_EXT_DIR/"
    fi
}


FIX_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

	if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "TRUE" ] && [ -d "$EXTRACTED_FIRM_DIR/system_ext" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system_ext"
		return 1
	fi

    if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "FALSE" ] && [[ -d "$EXTRACTED_FIRM_DIR/system_ext" ]]; then
        echo -e "- Copying system_ext content into system root"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system_ext"
        cp -a --preserve=all "$EXTRACTED_FIRM_DIR/system_ext" "$EXTRACTED_FIRM_DIR/system"

        echo -e "- Cleaning and merging system_ext file contexts and configs"
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
        if [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
        elif [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
        fi
    fi
}


FIX_SELINUX() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    echo -e "- Fixing selinux"

	local EXTRACTED_FIRM_DIR="$1"

	if [ -d "$EXTRACTED_FIRM_DIR/system_ext/apex" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system_ext"
	elif [ -d "$EXTRACTED_FIRM_DIR/system/system_ext/apex" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system_ext"
    elif [ -d "$EXTRACTED_FIRM_DIR/system/system/system_ext/apex" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="$EXTRACTED_FIRM_DIR/system/system/system_ext"
    fi

    if [ -n "$STOCK_VNDK_VERSION" ]; then
        SELINUX_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/mapping/${STOCK_VNDK_VERSION}.0.cil"
    else
        MANIFEST_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/vintf/manifest.xml"

        if [ ! -f "$MANIFEST_FILE" ]; then
            echo -e "- manifest.xml not found. Cannot determine VNDK version."
            return 1
        fi

        STOCK_VNDK_VERSION=$(grep -oP '(?<=<version>)[0-9]+' "$MANIFEST_FILE" | head -n1)

        if [ -z "$STOCK_VNDK_VERSION" ]; then
            echo -e "- Failed to extract VNDK version from manifest."
            return 1
        fi

        SELINUX_FILE="$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/mapping/${STOCK_VNDK_VERSION}.0.cil"
    fi

    echo -e "- Using SELinux mapping file: $SELINUX_FILE"

    if [ ! -f "$SELINUX_FILE" ]; then
        echo -e "- Error: SELinux file not found at $SELINUX_FILE"
        exit 1
    fi

    UNSUPPORTED_SELINUX=("audiomirroring" "fabriccrypto" "hal_dsms_default" "qb_id_prop" "hal_dsms_service" "proc_compaction_proactiveness" "sbauth" "ker_app" "kpp_app" "kpp_data" "attiqi_app" "kpoc_charger" "sec_diag" "mosey_app" "vendor_smcinvoke_device")

    for keyword in "${UNSUPPORTED_SELINUX[@]}"; do
        if grep -q "$keyword" "$SELINUX_FILE"; then
            sed -i "/$keyword/d" "$SELINUX_FILE"
        fi
    done

    REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' "$EXTRACTED_FIRM_DIR/system/system/etc/selinux/plat_sepolicy.cil" >/dev/null 2>&1
	REMOVE_LINE '(genfscon proc "/sys/kernel/firmware_config" (u object_r proc_fmw ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil" >/dev/null 2>&1
	REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_sepolicy.cil" >/dev/null 2>&1
    REMOVE_LINE 'init.svc.vendor.wvkprov_server_hal                           u:object_r:wvkprov_prop:s0' "$TARGET_ROM_SYSTEM_EXT_DIR/etc/selinux/system_ext_property_contexts" >/dev/null 2>&1
}


UPDATE_FLOATING_FEATURE() {
    local key="$1"
    local value="$2"
    if [[ -z "$value" ]]; then
        echo -e "- Skipping $key — no value found."
        return
    fi

    if grep -q "<${key}>.*</${key}>" "$TARGET_FLOATING_FEATURE"; then
        local current_line
        current_line=$(grep "<${key}>.*</${key}>" "$TARGET_FLOATING_FEATURE")
        local current_value
        current_value=$(echo -e "$current_line" | sed -E "s/.*<${key}>(.*)<\/${key}>.*/\1/")

        if [[ "$current_value" == "$value" ]]; then
            return
        fi

        local indent
        indent=$(echo -e "$current_line" | sed -E "s/(<${key}>.*<\/${key}>).*//")
        local line="${indent}<${key}>${value}</${key}>"
        sed -i "s|${indent}<${key}>.*</${key}>|$line|" "$TARGET_FLOATING_FEATURE"
        # echo -e "- Updated $key with ▶️ $value"
    else
        local line="    <$key>$value</$key>"
        sed -i "3i\\$line" "$TARGET_FLOATING_FEATURE"
        # echo -e "- Added $key with value ▶️ $value"
    fi
}


APPLY_CUSTOM_FLOATING_FEATURE() {
    echo -e ""
	echo -e "${YELLOW}Applying Custom Floating Feature.${NC}"
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
    echo -e "- Applying Stock Floating Feature."

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


APPLY_STOCK_CONFIG() {
    echo -e ""
	if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        echo -e "No target device is set. Just modifying ROM without any device config."
        return 1
    fi

	echo -e "${YELLOW}Applying $STOCK_DEVICE device config.${NC}"
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ ! -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo -e "- Config file for $STOCK_DEVICE not found in $DEVICES_DIR"
        return 1
	fi

    if [ -f "$DEVICES_DIR/$STOCK_DEVICE/config" ]; then
        echo -e "- $STOCK_DEVICE config found."
        export STOCK_VNDK_VERSION="$(grep -m1 '^STOCK_VNDK_VERSION=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
        export STOCK_HAS_SEPARATE_SYSTEM_EXT="$(grep -m1 '^STOCK_HAS_SEPARATE_SYSTEM_EXT=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export STOCK_DVFS_FILENAME="$(grep -m1 '^STOCK_DVFS_FILENAME=' "$DEVICES_DIR/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    fi

    export STOCK_FLOATING_FEATURE="$DEVICES_DIR/$STOCK_DEVICE/floating_feature.xml"
	export STOCK_SIOP_FILENAME="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_FLOATING_FEATURE" | tr -d '\r' | xargs)"
	export DEVICE_TYPE="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" {print $3}' "$STOCK_FLOATING_FEATURE")"

	# FIX SYSTEM_EXT.
    FIX_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"

	# FIX VNDK.
	FIX_VNDK

    # Apply stock floating feature.
	APPLY_STOCK_FLOATING_FEATURE

    # Fix unsupported BPF error for kernels lower than 5.10.
    # if [ "$USE_UI_8_TETHERING_APEX" = "True" ]; then
        # cp -rfa "$(pwd)/QuantumROM/Mods/Tethering_Apex/UI-8/." "$EXTRACTED_FIRM_DIR/"
    # fi

    if [ "$DEVICE_TYPE" = "jdm" ]; then
	    echo -e "- Applying jdm device feature."
	    APPLY_JDM_SPECIAL "$EXTRACTED_FIRM_DIR"
    else
	    rm -rf "$EXTRACTED_FIRM_DIR/system/system/cameradata/portrait_data"
	fi

	rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/init"/rscmgr*.rc
	find "$EXTRACTED_FIRM_DIR/system/system/media" -maxdepth 1 -type f \( -iname "*.spi" -o -iname "*.qmg" -o -iname "*.txt" \) -delete
	rm -rf $EXTRACTED_FIRM_DIR/product/overlay/framework-res*auto_generated_rro_product.apk
	cp -a "$DEVICES_DIR/$STOCK_DEVICE/Stock/." "$EXTRACTED_FIRM_DIR/"
}


BUILD_PROP() {
    if [ "$#" -lt 3 ]; then
        echo -e "Usage: BUILD_PROP <EXTRACTED_FIRM_DIR> <PARTITION> <KEY> [VALUE]"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"
    local KEY="$3"
    local VALUE="${4-}"

    local FILE=""

    case "$PARTITION" in
        system)
            FILE="$EXTRACTED_FIRM_DIR/system/system/build.prop"
            ;;
        vendor)
            FILE="$EXTRACTED_FIRM_DIR/vendor/build.prop"
            ;;
        product)
            FILE="$EXTRACTED_FIRM_DIR/product/etc/build.prop"
            ;;
        system_ext)
            FILE="$EXTRACTED_FIRM_DIR/system_ext/etc/build.prop"
            ;;
        odm)
            FILE="$EXTRACTED_FIRM_DIR/odm/etc/build.prop"
            ;;
        *)
            echo -e "Unknown partition: $PARTITION"
            return 1
            ;;
    esac

    if [ ! -f "$FILE" ]; then
        echo -e "build.prop not found: $FILE"
        return 1
    fi

    if grep -q "^${KEY}=" "$FILE"; then
        if [ -z "$VALUE" ]; then
            # Keep key, remove value
            sed -i "s|^${KEY}=.*|${KEY}=|" "$FILE"
        else
            # Replace value
            sed -i "s|^${KEY}=.*|${KEY}=${VALUE}|" "$FILE"
        fi
    else
        # Append if not exists
        if [ -z "$VALUE" ]; then
            echo -e "${KEY}=" >> "$FILE"
        else
            echo -e "${KEY}=${VALUE}" >> "$FILE"
        fi
    fi
}


REMOVE_TLC_ICC() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ -d "$EXTRACTED_FIRM_DIR/vendor" ]; then
        rm -f \
        "$EXTRACTED_FIRM_DIR/vendor/bin/hw/vendor.samsung.hardware.tlc.iccc@1.0-service" \
        "$EXTRACTED_FIRM_DIR/vendor/etc/init/vendor.samsung.hardware.tlc.iccc@1.0-service.rc" \
        "$EXTRACTED_FIRM_DIR/vendor/etc/vintf/manifest/vendor.samsung.hardware.tlc.iccc@1.0-manifest.xml" \
        "$EXTRACTED_FIRM_DIR/vendor/lib64/vendor.samsung.hardware.tlc.iccc@1.0-impl.so" \
        "$EXTRACTED_FIRM_DIR/vendor/lib64/vendor.samsung.hardware.tlc.iccc@1.0.so"
    fi
}


DISABLE_SECURITY() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    echo -e "Disabling security related things."

    if [ -f "${EXTRACTED_FIRM_DIR}/product/etc/build.prop" ]; then
        echo "- Disabling factory reset protection from product."
        BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.frp.pst" ""
    fi

	if [ -f "${EXTRACTED_FIRM_DIR}/vendor/build.prop" ]; then
        echo "- Disabling factory reset protection from vendor."
		BUILD_PROP "$EXTRACTED_FIRM_DIR" "vendor" "ro.frp.pst" ""
    fi

    if [ -f "${EXTRACTED_FIRM_DIR}/vendor/recovery-from-boot.p" ]; then
        echo "- Disabling stock recovery restoration."
        rm -rf "${EXTRACTED_FIRM_DIR}/vendor/recovery-from-boot.p"
    fi

	DISABLE_FBE "$EXTRACTED_FIRM_DIR"
	DISABLE_FDE "$EXTRACTED_FIRM_DIR"
	REMOVE_TLC_ICC "$EXTRACTED_FIRM_DIR"
}


APPLY_JDM_SPECIAL() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SamSungCamera"
    cp -rfa "$(pwd)/QuantumROM/Mods/Apps/JDM_Special/SamSungCamera/." "$EXTRACTED_FIRM_DIR/"
}


APPLY_CUSTOM_FEATURES() {
    echo -e ""
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"

    echo -e "${YELLOW}Applying usefull features.${NC}"
	DISABLE_SECURITY "$EXTRACTED_FIRM_DIR"
	
	echo -e "- Adding build prop tweak."
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.product.locale" "en-US"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.product.locale" "en-US"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "fw.max_users" "5"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "fw.show_multiuserui" "1"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "wifi.interface=" "wlan0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "wlan.wfd.hdcp" "disabled"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.hwui.renderer" "skiavk"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.telephony.sim_slots.count" "2"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.surface_flinger.protected_contents" "true"

	echo -e "- Adding China smart manager."
	rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/AppLock"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/Firewall"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SmartManager_v5"
    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app/SmartManagerCN"
	cp -rfa "$(pwd)/QuantumROM/Mods/SMART_MANAGER_CN/." "$EXTRACTED_FIRM_DIR/"
	UPDATE_FLOATING_FEATURE "SEC_FLOATING_FEATURE_SMARTMANAGER_CONFIG_PACKAGE_NAME" "com.samsung.android.sm_cn"

	echo -e "- Adding full OneUI and important apps."
	# if [ ! -d "$EXTRACTED_FIRM_DIR/product/priv-app/AiWallpaper" ]; then
        # cp -rfa "$(pwd)/QuantumROM/Mods/Apps/AiWallpaper/"* "$EXTRACTED_FIRM_DIR/"
    # fi

    # if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/app/ClockPackage" ]; then
        #vcp -rfa "$(pwd)/QuantumROM/Mods/Apps/ClockPackage/"* "$EXTRACTED_FIRM_DIR/"
    # fi

    # if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/app/SecCalculator_R" ]; then
        # cp -rfa "$(pwd)/QuantumROM/Mods/Apps/SecCalculator_R/"* "$EXTRACTED_FIRM_DIR/"
    # fi

	if [ ! -d "$EXTRACTED_FIRM_DIR/system/system/priv-app/PhotoEditor_AIFull" ]; then
	    rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailasso"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/ailassomatting"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/inpainting"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/objectremoval"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/reflectionremoval"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/shadowremoval"
		rm -rf "$EXTRACTED_FIRM_DIR/system/system/etc/style_transfer"
	    rm -rf "$EXTRACTED_FIRM_DIR/system/system/priv-app"/PhotoEditor_*
        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/PhotoEditor_AIFull/"* "$EXTRACTED_FIRM_DIR"
    fi

    # Apply custom floating feature.
	APPLY_CUSTOM_FLOATING_FEATURE

	# Google photos unlimited backup.
	# https://github.com/VehanRajintha/Free-Unlimited-Google-Cloud-Backup-Magisk-Module/releases/tag/Assets
	cp -rfa "$(pwd)/QuantumROM/Mods/GPhotos/." "$EXTRACTED_FIRM_DIR/"

    # Fix Samsung AI Photo Editor Crash.
	sed -i '0,/"ModelType": "MODEL_TYPE_INSTANCE_CAPTURE"/s//"ModelType": "MODEL_TYPE_OBJ_INSTANCE_CAPTURE"/' "$EXTRACTED_FIRM_DIR/system/system/cameradata/portrait_data/single_bokeh_feature.json"

	# Remove power and data usage permissions for certain apps when Power Saver and Data Saver are always enabled.
	# sed -i '/^[[:space:]]*<allow-in-power-save/d; /^[[:space:]]*<allow-in-data-usage-save/d' "$EXTRACTED_FIRM_DIR/product/etc/sysconfig/"*.xml "$EXTRACTED_FIRM_DIR/system/system/etc/sysconfig/"*.xml
}


DECODE_OMC() {
    echo " "

    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <OUT_DIR>"
        return 1
    fi

    echo -e "Decoding CSC - odm,optics."

    if ! command -v java >/dev/null 2>&1; then
        echo -e "Java is not installed."
        return 1
    fi

    local FW_DIR="$1"
	local OUT_DIR="$2"

    if [ -d "${FW_DIR}/odm/etc/omc" ]; then
        rm -rf "${OUT_DIR}/odm_decoded"

        echo "Decoding odm/etc/omc in ${OUT_DIR}"

        java -jar "$omc_decoder" \
            -i "${FW_DIR}/odm/etc/omc" \
            -o "${OUT_DIR}/odm_decoded" \
            >/dev/null 2>&1 || {
                echo -e "Failed decoding odm/etc/omc."
            }
	else
	     echo "No odm found."
    fi

    if [ -d "${FW_DIR}/optics" ]; then
        rm -rf "${OUT_DIR}/optics_decoded"

        echo "Decoding optics in ${OUT_DIR}"

        java -jar "$omc_decoder" \
            -i "${FW_DIR}/optics" \
            -o "${OUT_DIR}/optics_decoded" \
            >/dev/null 2>&1 || {
                echo -e "Failed decoding optics."
            }
	else
	     echo "No optics found."
    fi
}


GEN_FS_CONFIG() {
    echo " "

    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <PARTITION_FOLDER_NAME>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"

    [ ! -d "${EXTRACTED_FIRM_DIR}/$PARTITION" ] && {
        echo -e "- Partition not found: $PARTITION"
        return 1
    }

    [ "$PARTITION" = "config" ] && return

    local FS_CONFIG="${EXTRACTED_FIRM_DIR}/config/${PARTITION}_fs_config"
    local TMP_EXISTING="$(mktemp)"

    touch "$FS_CONFIG"

    echo -e "Generating fs_config for partition: $PARTITION"

    awk '{print $1}' "$FS_CONFIG" | sort -u > "$TMP_EXISTING"

    find "${EXTRACTED_FIRM_DIR}/$PARTITION" -mindepth 1 \( -type f -o -type d -o -type l \) | while IFS= read -r item; do

        REL_PATH="${item#${EXTRACTED_FIRM_DIR}/$PARTITION/}"
        PATH_ENTRY="$PARTITION/$REL_PATH"

        grep -qxF "$PATH_ENTRY" "$TMP_EXISTING" && continue

        if [ -d "$item" ]; then
            echo -e "- Adding: $PATH_ENTRY 0 0 0755"
            printf "%s 0 0 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"

        else
            if [[ "$REL_PATH" == */bin/* ]]; then
                echo -e "- Adding: $PATH_ENTRY 0 2000 0755"
                printf "%s 0 2000 0755\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            else
                echo -e "- Adding: $PATH_ENTRY 0 0 0644"
                printf "%s 0 0 0644\n" "$PATH_ENTRY" >> "$FS_CONFIG"
            fi
        fi

    done

    rm -f "$TMP_EXISTING"

    echo -e "- $PARTITION fs_config generated"
}


GEN_FILE_CONTEXTS() {
    echo " "

    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <PARTITION_FOLDER_NAME>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local PARTITION="$2"

    [ ! -d "${EXTRACTED_FIRM_DIR}/$PARTITION" ] && {
        echo -e "- Partition not found: $PARTITION"
        return 1
    }

    [ "$PARTITION" = "config" ] && return

    escape_path() {
        local path="$1"
        local result=""
        local c

        for ((i=0; i<${#path}; i++)); do
            c="${path:i:1}"

            case "$c" in
                '.'|'+'|'['|']'|'*'|'?'|'^'|'$'|'\\')
                    result+="\\$c"
                    ;;
                *)
                    result+="$c"
                    ;;
            esac
        done

        printf '%s' "$result"
    }

    local FILE_CONTEXTS="${EXTRACTED_FIRM_DIR}/config/${PARTITION}_file_contexts"

    touch "$FILE_CONTEXTS"

    echo -e "Generating file_contexts for partition: $PARTITION"

    declare -A EXISTING=()

    while IFS= read -r line || [[ -n "$line" ]]; do
        [ -z "$line" ] && continue

        local PATH_ONLY=$(echo -e "$line" | awk '{print $1}')

        EXISTING["$PATH_ONLY"]=1

    done < "$FILE_CONTEXTS"

    find "${EXTRACTED_FIRM_DIR}/$PARTITION" -mindepth 1 \( -type f -o -type d -o -type l \) | while IFS= read -r item; do

        local REL_PATH="${item#${EXTRACTED_FIRM_DIR}/$PARTITION}"
        local PATH_ENTRY="/$PARTITION$REL_PATH"

        local ESCAPED_PATH="/$(escape_path "${PATH_ENTRY#/}")"

        [[ -n "${EXISTING[$ESCAPED_PATH]-}" ]] && continue

        local CONTEXT="u:object_r:system_file:s0"
        
        if [[ "$PARTITION" == odm* || "$PARTITION" == vendor* ]]; then
            CONTEXT="u:object_r:vendor_file:s0"
        fi

        local BASENAME=$(basename "$item")

        if [[ "$BASENAME" == "linker" || "$BASENAME" == "linker64" ]]; then
            CONTEXT="u:object_r:system_linker_exec:s0"
        fi

        if [[ "$BASENAME" == "[" ]]; then
            CONTEXT="u:object_r:system_file:s0"
        fi

        printf "%s %s\n" "$ESCAPED_PATH" "$CONTEXT" >> "$FILE_CONTEXTS"

        echo -e "- Added: $ESCAPED_PATH"

        EXISTING["$ESCAPED_PATH"]=1

    done

    echo -e "- $PARTITION file_contexts generated"

    unset EXISTING
}


BUILD_IMG() {
    echo " "

    if [ "$#" -ne 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> all|img_name <FILE_SYSTEM> <OUT_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local MODE="$2"
    local FILE_SYSTEM="$3"
    local OUT_DIR="$4"

    mkdir -p "$OUT_DIR"

    build_img() {
        local PARTITION="$1"

        mkdir -p "${EXTRACTED_FIRM_DIR}/${PARTITION}/lost+found"

        GEN_FS_CONFIG "$EXTRACTED_FIRM_DIR" "$PARTITION"
        GEN_FILE_CONTEXTS "$EXTRACTED_FIRM_DIR" "$PARTITION"

        local SOURCE_DIR="${EXTRACTED_FIRM_DIR}/$PARTITION"
        local OUT_IMG="$OUT_DIR/${PARTITION}.img"
        local FS_CONFIG="${EXTRACTED_FIRM_DIR}/config/${PARTITION}_fs_config"
        local FILE_CONTEXTS="${EXTRACTED_FIRM_DIR}/config/${PARTITION}_file_contexts"

        [[ -d "$SOURCE_DIR" ]] || return

        local EXTRACTED_SIZE=$(du -sb --apparent-size "$SOURCE_DIR" | cut -f1)
        local MOUNT_POINT="/$PARTITION"

        rm -rf "$OUT_IMG"

        [[ -f "$FS_CONFIG" ]] || {
            echo -e "Warning: $FS_CONFIG missing, skipping $PARTITION"
            return
        }

        [[ -f "$FILE_CONTEXTS" ]] || {
            echo -e "Warning: $FILE_CONTEXTS missing, skipping $PARTITION"
            return
        }

        sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"
        sort -u "$FS_CONFIG" -o "$FS_CONFIG"

        if [[ "$FILE_SYSTEM" == "erofs" ]]; then
            echo " "
            echo -e "Building erofs image: $OUT_IMG"

            $mkfs_erofs \
                --mount-point="$MOUNT_POINT" \
                --fs-config-file="$FS_CONFIG" \
                --file-contexts="$FILE_CONTEXTS" \
                -z lz4hc \
                -b 4096 \
                -T 1199145600 \
                "$OUT_IMG" "$SOURCE_DIR" >/dev/null 2>&1

        elif [[ "$FILE_SYSTEM" == "ext4" ]]; then
            echo " "
            echo -e "Building ext4 image: $OUT_IMG"

            SIZE=$(((EXTRACTED_SIZE + 4095) / 4096 * 4096))
            EXTENDED_SIZE=$((SIZE + SIZE / 5))

            if [ "$EXTENDED_SIZE" -lt "4349952" ]; then
                EXTENDED_SIZE="4349952"
            fi

            $make_ext4fs \
                -l "$EXTENDED_SIZE" \
                -J \
                -b 4096 \
                -S "$FILE_CONTEXTS" \
                -C "$FS_CONFIG" \
                -a "$MOUNT_POINT" \
                -L "$PARTITION" \
                "$OUT_IMG" "$SOURCE_DIR"

            resize2fs -M "$OUT_IMG"

        elif [[ "$FILE_SYSTEM" == "f2fs" ]]; then
            echo " "
            echo -e "Building f2fs image: $OUT_IMG"

            SIZE=$(((EXTRACTED_SIZE + 511) / 512 * 512))
            EXTENDED_SIZE=$((SIZE + SIZE / 4))

            dd if=/dev/zero of="$OUT_IMG" bs=512 count=$((EXTENDED_SIZE / 512))

            $make_f2fs \
                -f -q \
                -g android \
                -O extra_attr,inode_checksum,sb_checksum,compression \
                -l "$MOUNT_POINT" \
                "$OUT_IMG"

            $sload_f2fs \
                -f "$SOURCE_DIR" \
                -C "$FS_CONFIG" \
                -s "$FILE_CONTEXTS" \
                -t "$MOUNT_POINT" \
                -P \
                -c \
                -L 2 \
                -a lz4 \
                "$OUT_IMG"

            img2simg "$OUT_IMG" "${OUT_IMG}.sparse"

            rm -rf "$OUT_IMG"
            mv "${OUT_IMG}.sparse" "$OUT_IMG"

        else
            echo -e "Unsupported filesystem: $FILE_SYSTEM"
            return
        fi
    }

    if [ "$MODE" = "all" ]; then

        for PART in "$EXTRACTED_FIRM_DIR"/*; do
            [[ -d "$PART" ]] || continue

            local PARTITION="$(basename "$PART")"

            [[ "$PARTITION" == "config" ]] && continue

            build_img "$PARTITION"
        done

    else
        build_img "$MODE"
    fi

    chown -R "$REAL_USER:$REAL_USER" "$OUT_DIR"
    chmod -R u+rwX "$OUT_DIR"
}


BUILD_SUPER_IMG() {
    echo " "

    local IMG_DIR="$1"
    local OUTPUT_DIR="$2"
    local OUTPUT_IMG="$OUTPUT_DIR/super.img"

    echo "Building: super.img"

    [ ! -d "$IMG_DIR" ] && {
        echo "- Input folder not found: $IMG_DIR"
        return 1
    }

    local PARTITIONS=""
    local IMAGES=""
    local TOTAL_SIZE=0
    local VALID_IMAGES=0

    rm -f "$OUTPUT_IMG"

    for img in "$IMG_DIR"/*.img; do
        [ -e "$img" ] || continue

        local name="$(basename "$img")"

        case "$name" in
            boot.img|init_boot.img|recovery.img|vbmeta.img|vbmeta_system.img|vbmeta_vendor.img|dtbo.img|userdata.img|cache.img|metadata.img|vendor_boot.img|super.img)
                echo "- Skipping $name"
                continue
                ;;
        esac

        local part_name="${name%.img}"
        local size=$(stat -c%s "$img")

        [ "$size" -le 0 ] && {
            echo "- Skipping empty image: $name"
            continue
        }

        echo "Adding: $part_name ($size bytes)"

        PARTITIONS+=" --partition ${part_name}:readonly:${size}:main"
        IMAGES+=" --image ${part_name}=$img"
        TOTAL_SIZE=$((TOTAL_SIZE + size))
        VALID_IMAGES=1
    done

    [ "$VALID_IMAGES" -eq 0 ] && {
        echo "- No valid logical partition images found"
        return 1
    }

    TOTAL_SIZE=$((TOTAL_SIZE + 4194304))

    $lpmake \
	    --device super:$TOTAL_SIZE \
        --metadata-size 65536 \
        --metadata-slots 2 \
		--group main:$TOTAL_SIZE \
		--block-size 4096 \
        $PARTITIONS \
        $IMAGES \
        --output "$OUTPUT_IMG"
}
