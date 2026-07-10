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
            FILE="${EXTRACTED_FIRM_DIR}/system/system/build.prop"
            ;;
        vendor)
            FILE="${EXTRACTED_FIRM_DIR}/vendor/build.prop"
            ;;
        product)
            FILE="${EXTRACTED_FIRM_DIR}/product/etc/build.prop"
            ;;
        system_ext)
            FILE="${EXTRACTED_FIRM_DIR}/system_ext/etc/build.prop"
            ;;
        odm)
            FILE="${EXTRACTED_FIRM_DIR}/odm/etc/build.prop"
            ;;
        *)
            echo -e "Unknown partition: $PARTITION"
            return 1
            ;;
    esac

    if [ ! -f "$FILE" ]; then
        echo -e "- File not found: $FILE"
        return 1
    fi

    local VALUE=$(grep -m1 "^${PROP}=" "$FILE" | cut -d'=' -f2-)

    if [ -z "$VALUE" ]; then
        return 1
    fi

    echo -e "$VALUE"
}


GET_FF_VALUE() {
    local KEY="$1"
    local FILE="$2"

    awk -F'[<>]' -v key="$KEY" '
        $2 == key { print $3; exit }
    ' "$FILE"
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

    rm -rf "$DOWN_DIR"
    mkdir -p "$DOWN_DIR"

    echo -e "======================================"
    echo -e "  Samsung FW Downloader   "
    echo -e "======================================"
    echo -e "MODEL: $MODEL | CSC: $CSC"

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
    python3 -m samloader -m "$MODEL" -r "$CSC" -i "$IMEI" download -O "$DOWN_DIR"
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

        echo -e "- super.img extraction complete"

    else
        echo -e "- No super.img found."
    fi
}


PREPARE_PARTITIONS() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    echo -e "Preparing partitions. $STOCK_DEVICE"
	
	if [ ! -d "$EXTRACTED_FIRM_DIR" ]; then
        echo -e "- Directory not found: $EXTRACTED_FIRM_DIR"
        return 1
    fi

    if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        export BUILD_PARTITIONS="odm,odm_dlkm,product,system,system_ext,system_dlkm,vendor,vendor_dlkm,odm_a,odm_dlkm_a,product_a,system_a,system_ext_a,system_dlkm_a,vendor_a,vendor_dlkm_a,optics,optics_a"
    fi

    if [ -n "$STOCK_DEVICE" ] && [ -f "${DEVICES_DIR}/$STOCK_DEVICE/config" ]; then
        export STOCK_HAS_AB_SLOT="$(grep -m1 '^STOCK_HAS_AB_SLOT=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    fi

	# Delete empty b slot images
    find "$EXTRACTED_FIRM_DIR" -type f -name '*_b.img' -size 0c -exec rm -rf {} +

    for img in "$EXTRACTED_FIRM_DIR"/*_a.img; do
        [ -f "$img" ] || continue

        new="${img%_a.img}.img"
        mv -f "$img" "$new"
    done

    IFS=',' read -r -a KEEP <<< "$BUILD_PARTITIONS"

    for i in "${!KEEP[@]}"; do
        KEEP[$i]=$(echo -e "${KEEP[$i]}" | xargs)
    done

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
				rm -rf "${EXTRACTED_FIRM_DIR}/$partition"
                python3 "$imgextractor_py" "$imgfile" "$EXTRACTED_FIRM_DIR"
                ;;

            erofs)
                echo " "
                echo -e "$partition.img Detected erofs. Size: $ORG_IMG_SIZE bytes. Extracting..."
				rm -rf "${EXTRACTED_FIRM_DIR}/$partition"
                "$extract_erofs" -i "$imgfile" -x -f -o "$EXTRACTED_FIRM_DIR" >/dev/null 2>&1
                ;;

            f2fs)
                echo " "
                echo -e "$partition.img Detected f2fs. Size: $ORG_IMG_SIZE bytes. Extracting..."
                bash "$QT_DIR/scripts/extract_img.sh" "$imgfile" "$EXTRACTED_FIRM_DIR"
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

	    if [ "${GITHUB_ACTIONS}" = "true" ]; then
            rm -f "$EXTRACTED_FIRM_DIR"/*.img
        fi

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

    if [ ! -d "${EXTRACTED_FIRM_DIR}/vendor/etc" ]; then
        return 1
    fi

    local fstab_files=$(grep -lr 'fileencryption' "${EXTRACTED_FIRM_DIR}/vendor/etc" 2>/dev/null)

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

    if [ ! -d "${EXTRACTED_FIRM_DIR}/vendor/etc" ]; then
        return 1
    fi

    local fstab_files=$(grep -lr 'forceencrypt' "${EXTRACTED_FIRM_DIR}/vendor/etc" 2>/dev/null)

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
    echo " "

    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <APKTOOL_JAR_DIR> <framework-res.apk>"
        return 1
    fi

	local APKTOOL="$1"
    local framework_apk="$2"

	if [ ! -f "$framework_apk" ]; then
        echo -e "- File not found: $framework_apk"
        return 1
    fi

    echo -e "Installing: $framework_apk"
    java -jar "$APKTOOL" install-framework "$framework_apk"
}


DECOMPILE() {
    echo " "

    if [ "$#" -ne 4 ]; then
        echo -e "Usage: DECOMPILE <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <FILE> <DECOMPILE_DIR>"
        return 1
    fi

    # apktool version-3
	# d = decompile
	# --force = force delete target decompile directory before decompile
	# --no-src = don't decompile dex file
	# --no-res = don't decode resources
	# --match-original = decompile everything as original
	# --frame-path = framework path
	# -o = decompile directory
	local APKTOOL="$1"
	local FRAMEWORK_DIR="$2"
    local FILE="$3"
    local DECOMPILE_DIR="$4"
    local BASENAME="$(basename "${FILE%.*}")"
    local OUT="$DECOMPILE_DIR/$BASENAME"

    echo -e "Decompiling: $FILE"

	if [ ! -f "$FILE" ]; then
        echo -e "- File not found: $FILE"
        return 1
    fi

	rm -rf "$OUT"
    java -jar "$APKTOOL" d --force --frame-path "$FRAMEWORK_DIR" --match-original "$FILE" -o "$OUT"
}


RECOMPILE() {
    echo " "

	if [ "$#" -ne 4 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <APKTOOL_JAR_DIR> <FRAMEWORK_DIR> <DECOMPILED_DIR> <RECOMPILE_DIR>"
        return 1
    fi

    # apktool version-3
	# b = recompile
	# --copy-original = use original manifest
	# --frame-path = framework path
	# -o = output /recompile file directory with filename
	local APKTOOL="$1"
	local FRAMEWORK_DIR="$2"
	local DECOMPILED_DIR="$3"
    local RECOMPILE_DIR="$4"

    local org_file_name=$(awk '/^apkFileName:/ {print $2}' "$DECOMPILED_DIR/apktool.yml")
    local name="${org_file_name%.*}"
    local ext="${org_file_name##*.}"
    local built_file="$RECOMPILE_DIR/${name}.$ext"

    echo -e "Recompiling: $DECOMPILED_DIR"

	if [ ! -d "$DECOMPILED_DIR" ]; then
        echo -e "- Directory not found: $DECOMPILED_DIR"
        return 1
    fi

    java -jar "$APKTOOL" b "$DECOMPILED_DIR" --copy-original --frame-path "$FRAMEWORK_DIR" -o "$built_file"
    rm -rf "$DECOMPILED_DIR"

	# Zipalign
	# echo " "
	# if [[ "$ext" == "apk" ]]; then
	    # echo -e "Zipaligning: $built_file to $final_file"
        # zipalign -v 4 "$built_file" "$final_file" >/dev/null 2>&1
		# rm -rf "$built_file"
    # fi
}


REPLACE_SMALI_METHOD() {
    local FILE="$1"
    local METHOD_NAME="$2"
    local NEW_BODY=$(echo -e "$3" | tail -n +2)

    echo -e "- Patching: $FILE"
    echo -e "  Method: $METHOD_NAME"

    if ! grep -Fq "$METHOD_NAME" "$FILE"; then
        echo -e "- Warning- Method: $METHOD_NAME not found in: $FILE"
        return 0
    fi

    # Extract method key (safe match)
    local METHOD_KEY=$(echo "$METHOD_NAME" | sed -E 's/.* ([^ ]+\().*/\1/')

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
    echo " "

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
	echo " "

	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

	echo -e "Patching flag secure."

	# https://github.com/ShaDisNX255/NcX_Stock/commit/c2cc85818df4fe040b4f89ca8f9b78e939b211b4
    # https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-86811691
    #
	# For android 13
	# local FILE="${1}/smali_classes3/com/android/server/wm/WindowState.smali"
	# local METHOD_NAME_1=".method public isSecureLocked()Z"
	# Only one method.
    #

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
    echo " "

	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "Patching secure folder."

	#https://forum.xda-developers.com/t/mods-samsung-not-android-mods-collection-exynos.3772017/post-86770885
    #
	# For android 13
	# local FILE_1="${1}/smali_classes2/com/android/server/knox/dar/DarManagerService.smali"
	# local METHOD_NAME_2=".method public isDeviceRootKeyInstalled()Z"
	# local METHOD_NAME_3=".method public isKnoxKeyInstallable()Z"
    #

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
	# METHOD_NAME_4 Is not available in Android 13
    local METHOD_NAME_4=".method public static isRootedDevice()Z"
    local REPLACE_BODY_2='
    .locals 1
 
    const/4 v0, 0x0
 
    return v0
    '
    REPLACE_SMALI_METHOD "$FILE_2" "$METHOD_NAME_4" "$REPLACE_BODY_2"
}


PATCH_PRIVATE_SHARE() {
    echo " "

	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "Patching private share."
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
    echo " "

	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "Disabling signature verification."
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
    echo " "

	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SERVICES_DIRECTORY>"
        return 1
    fi

    echo -e "Patching knox guard."
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
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

	if [ "$USE_ALT_SDHMS_APP" = "TRUE" ]; then
        echo "- Adding alternative SDHMS app."
		rm -rf "${EXTRACTED_FIRM_DIR}/system/priv-app/SamsungDeviceHealthManagerService"
		cp -a "$(pwd)/QuantumROM/Mods/Apps/SDHMS/." "${EXTRACTED_FIRM_DIR}/system"
    fi
}


PATCH_SSRM() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_SSRM_DIRECTORY>"
        return 1
    fi

    local SSRM_DIR="$1"
    local FILE="$SSRM_DIR/smali/com/android/server/ssrm/Feature.smali"

    echo -e "Patching SSRM."
    echo -e "- Patching: $FILE"

	if [ ! -f "$FILE" ]; then
	    echo "- File name not found: $FILE"
		return
	fi

    if FOUND=$(grep -E 'const-string v0, "dvfs_policy_.*_xx"' "$FILE"); then
        echo "- Found DVFS policy: $FOUND"

        if [ -n "$STOCK_DVFS_FILENAME" ]; then
            sed -i -E \
            's|const-string v0, "dvfs_policy_.*_xx"|const-string v0, "'"$STOCK_DVFS_FILENAME"'"|' \
            "$FILE"

            echo "- DVFS policy file name replaced to: ${STOCK_DVFS_FILENAME}"
        else
            echo "- STOCK_DVFS_FILENAME is empty. Skipping replacement."
        fi
    else
        echo "- DVFS policy file name not found."
    fi

    if FOUND=$(grep -E 'const-string v6, "siop_.*_.*"' "$FILE"); then
        echo "- Found SIOP policy: $FOUND"

        if [ -n "$STOCK_SIOP_POLICY_FILENAME" ]; then
            sed -i -E \
            's|const-string v6, "siop_.*_.*"|const-string v6, "'"$STOCK_SIOP_POLICY_FILENAME"'"|' \
            "$FILE"

            echo "- SIOP policy file name replaced to: ${STOCK_SIOP_POLICY_FILENAME}"
        else
            echo "- STOCK_SIOP_POLICY_FILENAME is empty. Skipping replacement."
        fi
    else
        echo "- SIOP policy file name not found."
    fi
}


PATCH_BT_LIB() {
    echo " "

	if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY> <WORK_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local WORK_DIR="$2"
	local BT_LIB_FILE="$WORK_DIR/libbluetooth_jni.so"

    echo -e "Patching Bluetooth library."
    # Get libbluetooth_jni.so
    if ! ls "$EXTRACTED_FIRM_DIR"/system/system/apex/com.android.bt*.apex >/dev/null 2>&1; then
        echo -e "- No bluetooth apex file found."
        return 1
    fi

    7z e "${EXTRACTED_FIRM_DIR}/system/system/apex/com.android.bt"*.apex \
        "apex_payload.img" -o"$WORK_DIR" -y >/dev/null

	debugfs -R "dump /lib64/libbluetooth_jni.so $WORK_DIR/libbluetooth_jni.so" \
        "$WORK_DIR/apex_payload.img" >/dev/null

	rm -rf "$WORK_DIR/apex_payload.img"

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

    local PATCHED=0

    for idx in "${!hex[@]}"; do
        (( idx >= 1000 )) && continue

        local from="${hex[$idx]}"
        local to="${hex[$((idx + 1000))]}"

        [ -z "$to" ] && continue

        # convert wildcard .... → regex
        local from_regex="$(echo "$from" | sed -E 's/\.\./[0-9a-f]{2}/g')"
        if perl -e '
            $/ = undef;
            open(F, shift) or exit 1;
            $_ = <F>;
            my $hex = unpack("H*", $_);
            exit ($hex =~ /'"$from_regex"'/i ? 0 : 1);
        ' "$BT_LIB_FILE"; then

            echo -e "- Found Bluetooth patch pattern [$idx]"

            HEX_PATCH "$BT_LIB_FILE" "$from" "$to" || return 1

            PATCHED=1
            mv -f "$BT_LIB_FILE" "${EXTRACTED_FIRM_DIR}/system/system/lib64/"
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
    echo " "

	if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIRECTORY>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local TARGET_ROM_SYSTEM_EXT_DIR="$(GET_SYSTEM_EXT_DIR "$EXTRACTED_FIRM_DIR")"

    echo -e "Checking $STOCK_DEVICE and $TARGET_DEVICE vndk version."
    export SDK="$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" ro.build.version.sdk_full)"
	echo "- Target rom SDK version: $SDK"
    if [ -f "${TARGET_ROM_SYSTEM_EXT_DIR}/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex" ]; then
        echo -e "- VNDK matched. ${TARGET_ROM_SYSTEM_EXT_DIR}/apex/com.android.vndk.v${STOCK_VNDK_VERSION}.apex"
    else
        echo -e "- VNDK mismatch. Adding SDK $SDK com.android.vndk.v${STOCK_VNDK_VERSION}.apex"
        rm -rf "${TARGET_ROM_SYSTEM_EXT_DIR}/apex/"com.android.vndk.v*.apex
        7z x "$VNDKS_COLLECTION/$SDK/${STOCK_VNDK_VERSION}.zip" -o"${TARGET_ROM_SYSTEM_EXT_DIR}/" -y >/dev/null 2>&1
    fi
}


ADD_SYSTEM_EXT_IN_SYSTEM_ROOT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    echo -e "- Copying system_ext content into system root"
    rm -rf "${EXTRACTED_FIRM_DIR}/system/system_ext"
    mv "${EXTRACTED_FIRM_DIR}/system_ext" "${EXTRACTED_FIRM_DIR}/system"

    echo -e "- Cleaning and merging system_ext file contexts and configs"
    # File paths
    SYSTEM_EXT_CONFIG_FILE="${EXTRACTED_FIRM_DIR}/config/system_ext_fs_config"
    SYSTEM_EXT_CONTEXTS_FILE="${EXTRACTED_FIRM_DIR}/config/system_ext_file_contexts"

    SYSTEM_CONFIG_FILE="${EXTRACTED_FIRM_DIR}/config/system_fs_config"
    SYSTEM_CONTEXTS_FILE="${EXTRACTED_FIRM_DIR}/config/system_file_contexts"

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

    rm -rf "$EXTRACTED_FIRM_DIR"/config/system_ext*
    export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system/system_ext"
}


SEPARATE_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

	echo "- Separating system_ext"
    mv "${EXTRACTED_FIRM_DIR}/system/system/system_ext" "${EXTRACTED_FIRM_DIR}/"
	ln -s /system_ext ${EXTRACTED_FIRM_DIR}/system/system/system_ext
	rm -rf "${EXTRACTED_FIRM_DIR}/system/system_ext"
	mkdir "${EXTRACTED_FIRM_DIR}/system/system_ext"

    SYSTEM_FS_CONFIG="${EXTRACTED_FIRM_DIR}/config/system_fs_config"
	SYSTEM_FILE_CONTEXTS="${EXTRACTED_FIRM_DIR}/config/system_file_contexts"
    
	SYSTEM_EXT_FS_CONFIG="${EXTRACTED_FIRM_DIR}/config/system_ext_fs_config"
	SYSTEM_EXT_FILE_CONTEXTS="${EXTRACTED_FIRM_DIR}/config/system_ext_file_contexts"

    # Process system_ext_file_contexts
    if grep -q '^/system/system/system_ext' "$SYSTEM_FILE_CONTEXTS"; then
        grep '^/system/system/system_ext' "$SYSTEM_FILE_CONTEXTS" > "$SYSTEM_EXT_FILE_CONTEXTS"
        sed -i '\|^/system/system/system_ext|d' "$SYSTEM_FILE_CONTEXTS"
        awk '{sub(/^\/system\/system\/system_ext/, "/system_ext"); print}' "$SYSTEM_EXT_FILE_CONTEXTS" > "$SYSTEM_EXT_FILE_CONTEXTS.tmp"  && \
        mv "$SYSTEM_EXT_FILE_CONTEXTS.tmp" "$SYSTEM_EXT_FILE_CONTEXTS"

        # Add object context line if missing
		grep -qxF '/system/system_ext u:object_r:system_file:s0' "$SYSTEM_FILE_CONTEXTS" || echo '/system/system_ext u:object_r:system_file:s0' >> "$SYSTEM_FILE_CONTEXTS"
		grep -qxF '/system/system/system_ext u:object_r:system_file:s0' "$SYSTEM_EXT_FILE_CONTEXTS" || echo '/system/system/system_ext u:object_r:system_file:s0' >> "$SYSTEM_EXT_FILE_CONTEXTS"

        grep -qxF '/ u:object_r:system_file:s0' "$SYSTEM_EXT_FILE_CONTEXTS" || echo '/ u:object_r:system_file:s0' >> "$SYSTEM_EXT_FILE_CONTEXTS"
		sort -u "$SYSTEM_EXT_FILE_CONTEXTS" -o "$SYSTEM_EXT_FILE_CONTEXTS"
    fi

    # Process system_ext_fs_config
    if grep -q '^system/system/system_ext' "$SYSTEM_FS_CONFIG"; then
        grep '^system/system/system_ext' "$SYSTEM_FS_CONFIG" > "$SYSTEM_EXT_FS_CONFIG"
        sed -i '\|^system/system/system_ext|d' "$SYSTEM_FS_CONFIG"
        awk '{sub(/^system\/system\/system_ext/, "system_ext"); print}' "$SYSTEM_EXT_FS_CONFIG" > "$SYSTEM_EXT_FS_CONFIG.tmp" &&  \
	    mv "$SYSTEM_EXT_FS_CONFIG.tmp" "$SYSTEM_EXT_FS_CONFIG"

        # Add default fs permissions if missing
        grep -qxF 'system/system_ext 0 0 0755' "$SYSTEM_FS_CONFIG" || echo 'system/system_ext 0 0 0755' >> "$SYSTEM_FS_CONFIG"
		grep -qxF 'system/system/system_ext 0 0 0644' "$SYSTEM_FS_CONFIG" || echo 'system/system/system_ext 0 0 0644' >> "$SYSTEM_FS_CONFIG"

        grep -qxF '/ 0 0 0755' "$SYSTEM_EXT_FS_CONFIG" || echo '/ 0 0 0755' >> "$SYSTEM_EXT_FS_CONFIG"
        grep -qxF 'system_ext/ 0 0 0755' "$SYSTEM_EXT_FS_CONFIG" || echo 'system_ext/ 0 0 0755' >> "$SYSTEM_EXT_FS_CONFIG"
		sort -u "$SYSTEM_EXT_FS_CONFIG" -o "$SYSTEM_EXT_FS_CONFIG"
    fi

    export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system_ext"
}


ADJUST_SYSTEM_EXT() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "FALSE" ]; then
        echo "- STOCK_HAS_SEPARATE_SYSTEM_EXT: $STOCK_HAS_SEPARATE_SYSTEM_EXT"

        if [ -d "${EXTRACTED_FIRM_DIR}/system/system/system_ext/etc" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system/system/system_ext"

        elif [ -d "${EXTRACTED_FIRM_DIR}/system/system_ext/etc" ]; then
            export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system/system_ext"
			
		elif [ -d "${EXTRACTED_FIRM_DIR}/system_ext/etc" ]; then
		    ADD_SYSTEM_EXT_IN_SYSTEM_ROOT "$EXTRACTED_FIRM_DIR"
        fi

	elif [ "$STOCK_HAS_SEPARATE_SYSTEM_EXT" = "TRUE" ]; then
        echo "STOCK_HAS_SEPARATE_SYSTEM_EXT: $STOCK_HAS_SEPARATE_SYSTEM_EXT"

        if [ -d "${EXTRACTED_FIRM_DIR}/system/system/system_ext/etc" ]; then
            SEPARATE_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"
        fi
    fi

    echo "- TARGET_ROM_SYSTEM_EXT_DIR set to: $TARGET_ROM_SYSTEM_EXT_DIR"
}


GET_SYSTEM_EXT_DIR() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"

    if [ -d "${EXTRACTED_FIRM_DIR}/system_ext/etc" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system_ext"
    elif [ -d "${EXTRACTED_FIRM_DIR}/system/system_ext/etc" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system/system_ext"
    elif [ -d "${EXTRACTED_FIRM_DIR}/system/system/system_ext/etc" ]; then
        export TARGET_ROM_SYSTEM_EXT_DIR="${EXTRACTED_FIRM_DIR}/system/system/system_ext"
    else
        return 1
    fi

    echo "$TARGET_ROM_SYSTEM_EXT_DIR"
}


PATCH_SELINUX() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local TARGET_ROM_SYSTEM_EXT_DIR="$(GET_SYSTEM_EXT_DIR "$EXTRACTED_FIRM_DIR")"

    echo -e "Patching selinux."

	UNSUPPORTED_SELINUX=("audiomirroring" "fabriccrypto" "hal_dsms_default" "qb_id_prop" "hal_dsms_service" "proc_compaction_proactiveness" "sbauth" "ker_app" "kpp_app" "kpp_data" "attiqi_app" "kpoc_charger" "sec_diag" "mosey_app" "vendor_smcinvoke_device")

    if [ -d "${EXTRACTED_FIRM_DIR}/system" ]; then
	    echo "- Patching selinux for system"

	    REMOVE_LINE '(genfscon sysfs "/bus/usb/devices" (u object_r sysfs_usb ((s0) (s0))))' \
		    "${EXTRACTED_FIRM_DIR}/system/system/etc/selinux/plat_sepolicy.cil" >/dev/null 2>&1
		REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' \
		    "${EXTRACTED_FIRM_DIR}/system/system/etc/selinux/plat_sepolicy.cil" >/dev/null 2>&1
    else
        echo -e "- No system directory found."
    fi

    if [ -d "$TARGET_ROM_SYSTEM_EXT_DIR" ]; then
        echo -e "- Patching selinux for system_ext"

        find "${TARGET_ROM_SYSTEM_EXT_DIR}/etc/selinux/mapping/" -type f -name "*.0.cil" | while read -r SELINUX_FILE; do
            # echo "  - Processing: $SELINUX_FILE"

            for keyword in "${UNSUPPORTED_SELINUX[@]}"; do
                if grep -qF "$keyword" "$SELINUX_FILE"; then
                    # echo "    - Removing keyword: $keyword"
                    sed -i "/$keyword/d" "$SELINUX_FILE"
                fi
            done
        done

	    REMOVE_LINE '(genfscon proc "/sys/kernel/firmware_config" (u object_r proc_fmw ((s0) (s0))))' \
	        "${TARGET_ROM_SYSTEM_EXT_DIR}/etc/selinux/system_ext_sepolicy.cil" >/dev/null 2>&1
	    REMOVE_LINE '(genfscon proc "/sys/vm/compaction_proactiveness" (u object_r proc_compaction_proactiveness ((s0) (s0))))' \
	        "${TARGET_ROM_SYSTEM_EXT_DIR}/etc/selinux/system_ext_sepolicy.cil" >/dev/null 2>&1
        REMOVE_LINE 'init.svc.vendor.wvkprov_server_hal                           u:object_r:wvkprov_prop:s0' \
	        "${TARGET_ROM_SYSTEM_EXT_DIR}/etc/selinux/system_ext_property_contexts" >/dev/null 2>&1
	else
        echo -e "- No system_ext directory found."
    fi
}


UPDATE_FLOATING_FEATURE() {
    if [ "$#" -ne 3 ]; then
        echo "Usage: ${FUNCNAME[0]} <FLOATING_FEATURE_FILE_DIRECTORY> <FLOATING_FEATURE_LINE> <VALUE>"
        return 1
    fi

    local FLOATING_FEATURE_FILE_DIRECTORY="$1"
    local key="$2"
    local value="$3"

    value=$(printf '%s' "$value" | tr -d '\r' | xargs)

    [ -z "$value" ] && {
        echo "- Skipping $key — no value found."
        return
    }

    local escaped_value
    escaped_value=$(printf '%s' "$value" | sed 's/[\/&]/\\&/g')

    if grep -Fq "<${key}>" "$FLOATING_FEATURE_FILE_DIRECTORY"; then

        local current_value
        current_value=$(
            sed -n "s|.*<${key}>\\(.*\\)</${key}>.*|\\1|p" \
            "$FLOATING_FEATURE_FILE_DIRECTORY" | head -n1 | xargs
        )

        if [ "$current_value" = "$value" ]; then
            return
        fi

        sed -i \
            "/<${key}>.*<\/${key}>/c\\    <${key}>${escaped_value}</${key}>" \
            "$FLOATING_FEATURE_FILE_DIRECTORY"

        #echo "- Updated $key with: $value"

    else
        sed -i \
            "3i\\    <${key}>${escaped_value}</${key}>" \
            "$FLOATING_FEATURE_FILE_DIRECTORY"

        #echo "- Added $key with value: $value"
    fi
}


APPLY_CUSTOM_FLOATING_FEATURE() {
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FLOATING_FEATURE_FILE_DIRECTORY>"
        return 1
    fi

	local FLOATING_FEATURE_FILE_DIRECTORY="$1"

	echo -e "- Applying Custom Floating Feature."
    #========== COMMON ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_COMMON_CONFIG_SEP_CATEGORY" "sep_basic"

    #============= AI ==========#
    sed -i '/SEC_FLOATING_FEATURE_COMMON_DISABLE_NATIVE_AI/d' "$FLOATING_FEATURE_FILE_DIRECTORY"
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_VISION_SUPPORT_AI_MY_FAVORITE_CONTENTS" "TRUE"

	#========== EDGE ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_COMMON_CONFIG_EDGE" "panel"
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_SYSTEMUI_SUPPORT_BRIEF_NOTIFICATION" "TRUE"
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_SYSTEMUI_CONFIG_EDGELIGHTING_FRAME_EFFECT" "frame_effect"

    #========== SCREEN RECORDER ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_FRAMEWORK_SUPPORT_SCREEN_RECORDER" "TRUE"

	#========== VOICE RECORDER ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_VOICERECORDER_CONFIG_DEF_MODE" "normal,interview,voicememo"

    #========== AUDIO ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_BT_RECORDING" "TRUE"

    #========== BATTERY ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_BATTERY_SUPPORT_BSOH_GALAXYDIAGNOSTICS" "TRUE"

    #========== SETTINGS ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_DEFAULT_DOUBLE_TAP_TO_WAKE" "TRUE"
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_SETTINGS_SUPPORT_FUNCTION_KEY_MENU" "TRUE"

    #========== SYSTEM ============#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_CPU_RESPONSIVENESS" "TRUE"
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_SYSTEM_SUPPORT_ENHANCED_PROCESSING" "TRUE"

    #========== LAUNCHER ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_LAUNCHER_SUPPORT_CLOCK_LIVE_ICON" "TRUE"
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" "HighEnd"

    #========== AOD ==========#
	if [ -d "$FIRM_DIR/$TARGET_DEVICE/system/system/priv-app"/AODService_* ]; then
	    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_FRAMEWORK_CONFIG_AOD_ITEM" "aodversion=7,clocktransition,coverboldfont"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_LCD_CONFIG_AOD_FULLSCREEN" "1"
    fi

    #========== CAMERA ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_CAMERA_SUPPORT_PRIVACY_TOGGLE" "TRUE"
}


APPLY_STOCK_ROM_FLOATING_FEATURE() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <FLOATING_FEATURE_FILE_DIRECTORY>"
        return 1
    fi

	local FLOATING_FEATURE_FILE_DIRECTORY="$1"

    echo "Applying Stock Floating Feature."

    #========== AUDIO ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_STAGE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_STAGE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_VOLUME_MONITOR" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_VOLUME_MONITOR" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_CONFIG_REMOTE_MIC" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_REMOTE_MIC" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_SOUNDALIVE_VERSION" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_GAIN" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_CONFIG_VOLUMEMONITOR_GAIN" "$STOCK_ROM_FLOATING_FEATURE")"

	UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_DUAL_SPEAKER" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_SUPPORT_DUAL_SPEAKER" "$STOCK_ROM_FLOATING_FEATURE")"

	UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_AUDIO_NUMBER_OF_SPEAKER" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_AUDIO_NUMBER_OF_SPEAKER" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== SETTINGS ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_ELECTRIC_RATED_VALUE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_ELECTRIC_RATED_VALUE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_BRAND_NAME" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_DEFAULT_FONT_SIZE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_SETTINGS_CONFIG_DEFAULT_FONT_SIZE" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== REFRESH RATE ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_SUPPORTED_REFRESH_RATE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_MODE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_CONFIG_HFR_DEFAULT_REFRESH_RATE" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== SYSTEM ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== LAUNCHER ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LAUNCHER_CONFIG_ANIMATION_TYPE" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== DISPLAY ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_CONFIG_CONTROL_AUTO_BRIGHTNESS" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_CONFIG_DEFAULT_SCREEN_MODE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_CONFIG_DEFAULT_SCREEN_MODE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_SUPPORT_NATURAL_SCREEN_MODE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_SUPPORT_NATURAL_SCREEN_MODE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LCD_SUPPORT_SCREEN_MODE_TYPE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LCD_SUPPORT_SCREEN_MODE_TYPE" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== CAMERA ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_BINNING" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_BINNING" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_MEMORY_USAGE_LEVEL" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_MEMORY_USAGE_LEVEL" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_QRCODE_INTERVAL" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_QRCODE_INTERVAL" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_UW_DISTORTION_CORRECTION" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_UW_DISTORTION_CORRECTION" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_AVATAR_MAX_FACE_NUM" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_AVATAR_MAX_FACE_NUM" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_STANDARD_CROP" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_CAMID_TELE_STANDARD_CROP" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_HIGH_RESOLUTION_MAX_CAPTURE" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_HIGH_RESOLUTION_MAX_CAPTURE" "$STOCK_ROM_FLOATING_FEATURE")"

    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_CAMERA_CONFIG_NIGHT_FRONT_DISPLAY_FLASH_TRANSPARENT" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_CAMERA_CONFIG_NIGHT_FRONT_DISPLAY_FLASH_TRANSPARENT" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== BIOAUTH ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_BIOAUTH_CONFIG_FINGERPRINT_FEATURES" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_BIOAUTH_CONFIG_FINGERPRINT_FEATURES" "$STOCK_ROM_FLOATING_FEATURE")"

    #========== LOCKSCREEN ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_PUNCHHOLE_VI" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_LOCKSCREEN_CONFIG_PUNCHHOLE_VI" "$STOCK_ROM_FLOATING_FEATURE")"

	#========== VIDEO EDITOR ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_COMMON_CONFIG_MULTIMEDIA_EDITOR_PLUGIN_PACKAGES" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_COMMON_CONFIG_MULTIMEDIA_EDITOR_PLUGIN_PACKAGES" "$STOCK_ROM_FLOATING_FEATURE")"

	#============= PHOTO REMASTER FIX ==========#
    if grep -q "<SEC_FLOATING_FEATURE_SAIV_CONFIG_MIDAS>" "$STOCK_ROM_FLOATING_FEATURE"; then
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_COMMON_CONFIG_MULTIMEDIA_EDITOR_PLUGIN_PACKAGES" \
        "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_COMMON_CONFIG_MULTIMEDIA_EDITOR_PLUGIN_PACKAGES" "$STOCK_ROM_FLOATING_FEATURE")"
    else
        sed -i '/<SEC_FLOATING_FEATURE_SAIV_CONFIG_MIDAS>/d' "$FLOATING_FEATURE_FILE_DIRECTORY"
    fi
	
	#========== SIM RELATED ==========#
    UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
    "SEC_FLOATING_FEATURE_COMMON_CONFIG_EMBEDDED_SIM_SLOTSWITCH" \
    "$(GET_FF_VALUE "SEC_FLOATING_FEATURE_COMMON_CONFIG_EMBEDDED_SIM_SLOTSWITCH" "$STOCK_ROM_FLOATING_FEATURE")"
}


REMOVE_CAMERA_FILES() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local LIB_DIRS=(
        "${EXTRACTED_FIRM_DIR}/system/system/lib"
        "${EXTRACTED_FIRM_DIR}/system/system/lib64"
    )

    local ARCSOFT_LIBS_LIST="${EXTRACTED_FIRM_DIR}/system/system/etc/public.libraries-arcsoft.txt"
    local CAMERA_LIBS_LIST="${EXTRACTED_FIRM_DIR}/system/system/etc/public.libraries-camera.samsung.txt"

    echo "- Removing camera files."

    local arcsoft_files=()
    local camera_files=()

    [ -f "$ARCSOFT_LIBS_LIST" ] && mapfile -t arcsoft_files < "$ARCSOFT_LIBS_LIST"
    [ -f "$CAMERA_LIBS_LIST" ] && mapfile -t camera_files < "$CAMERA_LIBS_LIST"

    local LIB_FILES=("${arcsoft_files[@]}" "${camera_files[@]}")

    for folder in "${LIB_DIRS[@]}"; do
        for file_name in "${LIB_FILES[@]}"; do
            local target="$folder/$file_name"

            if [ -f "$target" ]; then
			     #echo "Deleting: $target"
                rm -f "$target"
            fi
        done
    done

    rm -f "$ARCSOFT_LIBS_LIST"
    rm -f "$CAMERA_LIBS_LIST"

    rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app/SamsungCamera"
    rm -rf "${EXTRACTED_FIRM_DIR}/system/system/cameradata"

    export FIRST_CAM_LINE="$(
        grep -n '^    <SEC_FLOATING_FEATURE_CAMERA' \
        "${EXTRACTED_FIRM_DIR}/system/system/etc/floating_feature.xml" |
        head -n 1 | cut -d: -f1
    )"
}


FIX_BLUETOOTH() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local BUILD_BRAND=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "Build.BRAND")
	local SDK=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.build.version.sdk_full")
    local ANDROID_VERSION=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.system.build.version.release")

    if [ "$STOCK_DEVICE_CHIPSET" = "MediaTek" ] && [ "$BUILD_BRAND" != "MTK" ]; then
        echo "- Adding mediatek bluetooth apex."
        rm -f "${EXTRACTED_FIRM_DIR}"/system/system/apex/com.android.bt*.apex
        cp -rfa "$(pwd)/QuantumROM/MTK_SPECIAL/${SDK}/BT_APEX/system/." "${EXTRACTED_FIRM_DIR}/system/system"
    fi
}


FIX_CAMERA() {
    if [ "$#" -ne 1 ]; then
        echo "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
    local BUILD_BRAND=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "Build.BRAND")
    local ANDROID_VERSION=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.system.build.version.release")

    if [ "$STOCK_DEVICE_CHIPSET" = "MediaTek" ] && [ "$BUILD_BRAND" != "MTK" ]; then
        echo "- Adding mediatek camera related files."

        if [ ! -f "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}.zip" ]; then
            if curl -fsSL --connect-timeout 5 https://www.google.com >/dev/null; then
                wget --no-check-certificate \
                    "https://github.com/SN-Abdullah-Al-Noman/Samsung_Special/releases/download/Android_${ANDROID_VERSION}/MTK_Camera_Files_Android_${ANDROID_VERSION}.zip" \
                    -O "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}.zip"
            else
                echo "No internet connection available. Unable to download MTK_Camera_Files_Android_${ANDROID_VERSION}.zip."
                return 1
            fi
        fi

        if [ -s "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}.zip" ]; then
            rm -rf "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}"
			REMOVE_CAMERA_FILES "$EXTRACTED_FIRM_DIR"

            unzip -o \
                "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}.zip" \
                -d "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}" \
                >/dev/null 2>&1

            sed -i \
                "$((FIRST_CAM_LINE-1))r $(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}/system/etc/floating_feature.xml" \
                "${EXTRACTED_FIRM_DIR}/system/system/etc/floating_feature.xml"

			rm -rf "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}/system/etc/floating_feature.xml"

            echo "- Copying A34 mediatek camera related files."
            cp -rfa "$(pwd)/QuantumROM/Mods/Apps/MTK_Camera_Files_Android_${ANDROID_VERSION}/system/." "${EXTRACTED_FIRM_DIR}/system/system"
        fi
    fi
}


APPLY_STOCK_CONFIG() {
    echo " "

	echo -e "Applying $STOCK_DEVICE device config."
    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    local EXTRACTED_FIRM_DIR="$1"
	local FLOATING_FEATURE_FILE_DIRECTORY="${EXTRACTED_FIRM_DIR}/system/system/etc/floating_feature.xml"
	export TARGET_ROM_CPU_ABILIST="$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" ro.system.product.cpu.abilist)"

	if [ -z "$STOCK_DEVICE" ] || [ "$STOCK_DEVICE" = "None" ]; then
        echo -e "No target device is set. Just modifying ROM without any device config."
        return 1
    fi

    if [ ! -f "${DEVICES_DIR}/$STOCK_DEVICE/config" ]; then
        echo -e "Config file for $STOCK_DEVICE not found in $DEVICES_DIR"
        return 1
	fi

    if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system" ]; then
        echo -e "No usable extracted firmware found"
        return 1
	fi

    if [ -f "${DEVICES_DIR}/$STOCK_DEVICE/config" ]; then
        echo -e "$STOCK_DEVICE config found."
        export STOCK_VNDK_VERSION="$(grep -m1 '^STOCK_VNDK_VERSION=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
        export STOCK_HAS_SEPARATE_SYSTEM_EXT="$(grep -m1 '^STOCK_HAS_SEPARATE_SYSTEM_EXT=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    	export STOCK_DVFS_FILENAME="$(grep -m1 '^STOCK_DVFS_FILENAME=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export STOCK_DEVICE_CPU_ABILIST="$(grep -m1 '^STOCK_DEVICE_CPU_ABILIST=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export STOCK_DEVICE_CHIPSET="$(grep -m1 '^STOCK_DEVICE_CHIPSET=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export USE_ALT_SDHMS_APP="$(grep -m1 '^USE_ALT_SDHMS_APP=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
		export STOCK_HAS_ESIM_SUPPORT="$(grep -m1 '^STOCK_HAS_ESIM_SUPPORT=' "${DEVICES_DIR}/$STOCK_DEVICE/config" | cut -d= -f2 | tr -d '\r')"
    fi

	echo "Stock device vndk version: $STOCK_VNDK_VERSION"
    export STOCK_ROM_FLOATING_FEATURE="${DEVICES_DIR}/$STOCK_DEVICE/floating_feature.xml"
	export STOCK_SIOP_POLICY_FILENAME="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_SYSTEM_CONFIG_SIOP_POLICY_FILENAME" {print $3}' "$STOCK_ROM_FLOATING_FEATURE" | tr -d '\r' | xargs)"
	export STOCK_DEVICE_TYPE="$(awk -F'[<>]' '$2 == "SEC_FLOATING_FEATURE_COMMON_CONFIG_DEVICE_MANUFACTURING_TYPE" {print $3}' "$STOCK_ROM_FLOATING_FEATURE")"

	if [ "$STOCK_DEVICE_CPU_ABILIST" != "$TARGET_ROM_CPU_ABILIST" ]; then
        echo "CPU ABI MISMATCH!"
        echo "STOCK DEVICE CPU ABI: $STOCK_DEVICE_CPU_ABILIST"
        echo "TARGET ROM CPU ABI  : $TARGET_ROM_CPU_ABILIST"
        exit 1
    fi

    # Remove ESIM files if stock device does not support.
    if [ "$STOCK_HAS_ESIM_SUPPORT" = "FALSE" ]; then
        REMOVE_ESIM_FILES "$EXTRACTED_FIRM_DIR"
    fi

	# ADJUST SYSTEM_EXT PARTITION.
    ADJUST_SYSTEM_EXT "$EXTRACTED_FIRM_DIR"

	# FIX VNDK.
	FIX_VNDK "$EXTRACTED_FIRM_DIR"

	# FIX CAMERA IF NEED
	FIX_CAMERA "$EXTRACTED_FIRM_DIR"

    # Apply stock floating feature.
	APPLY_STOCK_ROM_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY"

    # Fix unsupported BPF error for kernels lower than 5.10.
    if [ "$USE_UI_8_TETHERING_APEX" = "True" ]; then
        cp -rfa "$(pwd)/QuantumROM/Mods/Tethering_Apex/UI-8/." "${EXTRACTED_FIRM_DIR}/"
    fi

    if [ "$STOCK_DEVICE_TYPE" = "jdm" ]; then
	    APPLY_JDM_SPECIAL "$EXTRACTED_FIRM_DIR"
    else
	    rm -rf "${EXTRACTED_FIRM_DIR}/system/system/cameradata/portrait_data"
	fi

	rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/init"/rscmgr*.rc
	find "${EXTRACTED_FIRM_DIR}/system/system/media" -maxdepth 1 -type f \( -iname "*.spi" -o -iname "*.qmg" -o -iname "*.txt" \) -delete
	rm -rf "$EXTRACTED_FIRM_DIR"/product/overlay/framework-res*auto_generated_rro_product.apk
	rm -rf ${EXTRACTED_FIRM_DIR}/product/overlay/SystemUI*auto_generated_rro_product.apk

	cp -a "${DEVICES_DIR}/$STOCK_DEVICE/Stock/." "${EXTRACTED_FIRM_DIR}/"

    if [ -d "${DEVICES_DIR}/${STOCK_DEVICE}/extra" ]; then
        cp -af "${DEVICES_DIR}/${STOCK_DEVICE}/extra/." "$(pwd)/OUT"
    fi

	BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.product.system.model" "$STOCK_DEVICE"
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
            local FILE="${EXTRACTED_FIRM_DIR}/system/system/build.prop"
            ;;
        vendor)
            local FILE="${EXTRACTED_FIRM_DIR}/vendor/build.prop"
            ;;
        product)
            local FILE="${EXTRACTED_FIRM_DIR}/product/etc/build.prop"
            ;;
        system_ext)
            local FILE="${EXTRACTED_FIRM_DIR}/system_ext/etc/build.prop"
            ;;
        odm)
            local FILE="${EXTRACTED_FIRM_DIR}/odm/etc/build.prop"
            ;;
        *)
            echo -e "Unknown partition: $PARTITION"
            return 1
            ;;
    esac

    if [ ! -f "$FILE" ]; then
        echo -e "- File not found: $FILE"
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

    if [ -d "${EXTRACTED_FIRM_DIR}/vendor" ]; then
        rm -f \
        "${EXTRACTED_FIRM_DIR}/vendor/bin/hw/vendor.samsung.hardware.tlc.iccc@1.0-service" \
        "${EXTRACTED_FIRM_DIR}/vendor/etc/init/vendor.samsung.hardware.tlc.iccc@1.0-service.rc" \
        "${EXTRACTED_FIRM_DIR}/vendor/etc/vintf/manifest/vendor.samsung.hardware.tlc.iccc@1.0-manifest.xml" \
        "${EXTRACTED_FIRM_DIR}/vendor/lib64/vendor.samsung.hardware.tlc.iccc@1.0-impl.so" \
        "${EXTRACTED_FIRM_DIR}/vendor/lib64/vendor.samsung.hardware.tlc.iccc@1.0.so"
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
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	echo -e "Applying jdm device feature."

	local EXTRACTED_FIRM_DIR="$1"
	local ANDROID_VERSION=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.system.build.version.release")

	rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app/SamsungCamera"

	if [ ! -f "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}.zip" ]; then
		if curl -fsSL --connect-timeout 5 https://www.google.com >/dev/null; then
            wget --no-check-certificate \
                "https://github.com/SN-Abdullah-Al-Noman/Samsung_Special/releases/download/Android_${ANDROID_VERSION}/JDM_Camera_Files_Android_${ANDROID_VERSION}.zip" \
                -O "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}.zip"
        else
            echo "- No internet connection available. Unable to download: Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip"
            return 1
        fi
    fi

    if [ -f "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}.zip" ]; then
        rm -rf "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}"
        unzip -o "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}.zip" \
            -d "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}" >/dev/null 2>&1

        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/JDM_Camera_Files_Android_${ANDROID_VERSION}/." "${EXTRACTED_FIRM_DIR}/"
    fi
}


ADD_SAMSUNG_FLAGSHIP_APPS() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

    echo -e "Adding samsung full ONEUI apps."

    local EXTRACTED_FIRM_DIR="$1"
    local FLOATING_FEATURE_FILE_DIRECTORY="${EXTRACTED_FIRM_DIR}/system/system/etc/floating_feature.xml"

    if [ ! -d "${EXTRACTED_FIRM_DIR}/system" ]; then
        echo "No extracted firmware found."
        return 1
    fi

    export PRODUCT_BRAND=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.product.system.brand")
    export ANDROID_VERSION=$(GET_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.system.build.version.release")
	
    if [ "$PRODUCT_BRAND" != "samsung" ]; then
        return 1
    fi

    # ================= SMART MANAGER =================
    echo "- Adding China smart manager."
	
	if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/priv-app/SmartManagerCN" ] && \
        [ ! -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}.zip" ]; then

        if curl -fsSL --connect-timeout 5 https://www.google.com >/dev/null; then
            wget --no-check-certificate \
                "https://github.com/SN-Abdullah-Al-Noman/Samsung_Special/releases/download/Android_${ANDROID_VERSION}/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}.zip" \
                -O "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}.zip"
        else
            echo "- No internet connection available. Unable to download: Samsung_SmartManagerCN_Android_${ANDROID_VERSION}.zip"
            return 1
        fi
    fi

    if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/priv-app/SmartManagerCN" ] && \
        [ -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}.zip" ]; then

        rm -rf "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}"
        unzip -o "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}.zip" \
            -d "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}" >/dev/null 2>&1

        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app/AppLock"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app/Firewall"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app/SmartManager_v5"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app/SmartManagerCN"

        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/Samsung_SmartManagerCN_Android_${ANDROID_VERSION}/." "${EXTRACTED_FIRM_DIR}/"

        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" \
            "SEC_FLOATING_FEATURE_SMARTMANAGER_CONFIG_PACKAGE_NAME" \
            "com.samsung.android.sm_cn"
    fi

    # ================= PHOTO EDITOR AI FULL =================
    echo "- Adding Photo editor ai full."
	
	if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/priv-app/PhotoEditor_AIFull" ] && \
        [ ! -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}.zip" ]; then

        if curl -fsSL --connect-timeout 5 https://www.google.com >/dev/null; then
            wget --no-check-certificate \
                "https://github.com/SN-Abdullah-Al-Noman/Samsung_Special/releases/download/Android_${ANDROID_VERSION}/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}.zip" \
                -O "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}.zip"
        else
            echo "- No internet connection available. Unable to download: Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}.zip"
            return 1
        fi
    fi

    if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/priv-app/PhotoEditor_AIFull" ] && \
        [ -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}.zip" ]; then

        rm -rf "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}"

        unzip -o "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}.zip" \
            -d "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}" >/dev/null 2>&1

        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/ailasso"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/ailassomatting"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/inpainting"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/objectremoval"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/reflectionremoval"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/shadowremoval"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/etc/style_transfer"
        rm -rf "${EXTRACTED_FIRM_DIR}/system/system/priv-app"/PhotoEditor_*

	    #========== GENAI ==========#
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_IMAGE_CLIPPER" "TRUE"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_OBJECT_ERASER" "TRUE"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_REFLECTION_ERASER" "TRUE"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SHADOW_ERASER" "TRUE"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SMART_LASSO" "TRUE"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_SPOT_FIXER" "TRUE"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_GENAI_SUPPORT_STYLE_TRANSFER" "TRUE"

        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/Samsung_PhotoEditor_AIFull_Android_${ANDROID_VERSION}/." "${EXTRACTED_FIRM_DIR}/"
    fi

    # Fix Samsung AI Photo Editor app Crash.
    if [ -f "${EXTRACTED_FIRM_DIR}/system/system/cameradata/portrait_data/single_bokeh_feature.json" ]; then
        sed -i '0,/"ModelType": "MODEL_TYPE_INSTANCE_CAPTURE"/s//"ModelType": "MODEL_TYPE_OBJ_INSTANCE_CAPTURE"/' \
        "${EXTRACTED_FIRM_DIR}/system/system/cameradata/portrait_data/single_bokeh_feature.json"
    fi

    # ================= OCR DATA PROVIDER =================
    echo "- Adding Samsung OCR Data Provider."

    if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/app/OCRDataProvider" ] && \
        [ ! -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip" ]; then

		if curl -fsSL --connect-timeout 5 https://www.google.com >/dev/null; then
            wget --no-check-certificate \
                "https://github.com/SN-Abdullah-Al-Noman/Samsung_Special/releases/download/Android_${ANDROID_VERSION}/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip" \
                -O "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip"
        else
            echo "- No internet connection available. Unable to download: Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip"
            return 1
        fi
    fi

    if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/app/OCRDataProvider" ] && \
        [ -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip" ]; then

        rm -rf "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}"
        unzip -o "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}.zip" \
            -d "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}" >/dev/null 2>&1

	    #============= OCR ==========#
        sed -i '/SEC_FLOATING_FEATURE_CAMERA_CONFIG_OCR_ENGINE_UNSUPPORT /d' "$FLOATING_FEATURE_FILE_DIRECTORY"
        UPDATE_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY" "SEC_FLOATING_FEATURE_CAMERA_CONFIG_STRIDE_OCR_VERSION" "V2"

        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/Samsung_OCRDataProvider_Android_${ANDROID_VERSION}/." "${EXTRACTED_FIRM_DIR}/"

		if [ ! -d "${EXTRACTED_FIRM_DIR}/system/system/app/OCRDataProvider" ]; then
	        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/OCR/." "${EXTRACTED_FIRM_DIR}/"
        fi
    fi

    # ================= IMPORTANT APPS =================
	echo "- Adding Samsung Important Apps."

    if [ ! -f "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}.zip" ]; then
        if curl -fsSL --connect-timeout 5 https://www.google.com >/dev/null; then
            wget --no-check-certificate \
                "https://github.com/SN-Abdullah-Al-Noman/Samsung_Special/releases/download/Android_${ANDROID_VERSION}/Samsung_Important_Apps_Android_${ANDROID_VERSION}.zip" \
               -O "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}.zip"
        else
            echo "No internet connection available. Unable to download: Samsung_Important_Apps_Android_${ANDROID_VERSION}.zip"
            return 1
        fi
    fi

    if [ -s "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}.zip" ]; then
        rm -rf "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}"
        unzip -o "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}.zip" \
            -d "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}" >/dev/null 2>&1

        cp -rfa "$(pwd)/QuantumROM/Mods/Apps/Samsung_Important_Apps_Android_${ANDROID_VERSION}/." "${EXTRACTED_FIRM_DIR}/"
    fi

    chown -R "$REAL_USER:$REAL_USER" "$EXTRACTED_FIRM_DIR"
    chmod -R u+rwX "$EXTRACTED_FIRM_DIR"
}


APPLY_CUSTOM_FEATURES() {
    echo " "

    if [ "$#" -ne 1 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR>"
        return 1
    fi

	local EXTRACTED_FIRM_DIR="$1"
	local FLOATING_FEATURE_FILE_DIRECTORY="${EXTRACTED_FIRM_DIR}/system/system/etc/floating_feature.xml"

	if [ ! -d "${EXTRACTED_FIRM_DIR}/system" ]; then
		echo "No extracted firmware found."
        return 1
    fi

    echo -e "Applying usefull features."

	echo -e "- Adding build prop tweak."
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.product.locale" "en-US"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "fw.max_users" "5"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "fw.show_multiuserui" "1"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "wifi.interface=" "wlan0"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "wlan.wfd.hdcp" "disabled"
    BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "debug.hwui.renderer" "skiavk"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.telephony.sim_slots.count" "2"
	BUILD_PROP "$EXTRACTED_FIRM_DIR" "system" "ro.surface_flinger.protected_contents" "true"

	BUILD_PROP "$EXTRACTED_FIRM_DIR" "product" "ro.product.locale" "en-US"

    # Apply custom floating feature.
	APPLY_CUSTOM_FLOATING_FEATURE "$FLOATING_FEATURE_FILE_DIRECTORY"

	# Fix samsung device health manager service
	UPDATE_SDHMS "$EXTRACTED_FIRM_DIR"

	chown -R "$REAL_USER:$REAL_USER" "$EXTRACTED_FIRM_DIR"
    chmod -R u+rwX "$EXTRACTED_FIRM_DIR"
	
	if [ -d "$(pwd)/QuantumROM/usefull_things" ]; then
        cp -a "$(pwd)/QuantumROM/usefull_things/." "$(pwd)/OUT"
    fi
}


DECODE_OMC() {
    echo " "

    if [ "$#" -ne 2 ]; then
        echo -e "Usage: ${FUNCNAME[0]} <EXTRACTED_FIRM_DIR> <OUT_DIR>"
        return 1
    fi

    echo -e "Decoding CSC - odm,optics."

    if ! command -v java >/dev/null 2>&1; then
        echo -e "- Java is not installed."
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
                echo -e "- Failed decoding odm/etc/omc."
            }
	else
	     echo "- No odm found."
    fi

    if [ -d "${FW_DIR}/optics" ]; then
        rm -rf "${OUT_DIR}/optics_decoded"

        echo "Decoding optics in ${OUT_DIR}"

        java -jar "$omc_decoder" \
            -i "${FW_DIR}/optics" \
            -o "${OUT_DIR}/optics_decoded" \
            >/dev/null 2>&1 || {
                echo -e "- Failed decoding optics."
            }
	else
	     echo "- No optics found."
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
