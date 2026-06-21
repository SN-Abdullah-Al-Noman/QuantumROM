#!/bin/bash

set -e

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <IMG_LOCATION> <OUT_DIR>"
    exit 1
fi

IMG_NAME="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
FIRM_DIR="$2"

if [ ! -f "$IMG_NAME" ]; then
    echo "- ERROR: Image not found"
    exit 1
fi

IMG_NAME_BASE=$(basename "$IMG_NAME" .img)
SRC_MOUNT="${FIRM_DIR}/${IMG_NAME_BASE}_mount"

FILE_CONTEXTS="${FIRM_DIR}/config/${IMG_NAME_BASE}_file_contexts"
FS_CONFIG="${FIRM_DIR}/config/${IMG_NAME_BASE}_fs_config"

# umount img if previously mounted
umount "$SRC_MOUNT" 2>/dev/null || true
rm -rf "$SRC_MOUNT"

rm -rf "${FIRM_DIR}/$IMG_NAME_BASE"
mkdir "${FIRM_DIR}/$IMG_NAME_BASE"

# config directory
mkdir -p "${FIRM_DIR}/config"
mkdir -p "$SRC_MOUNT"


# Mount img
mount -o ro "$IMG_NAME" "$SRC_MOUNT"

FC_SOURCE=$(find "$SRC_MOUNT" -type f \( \
-name "file_contexts" -o \
-name "file_contexts.bin" -o \
-name "*_file_contexts" -o \
-name "plat_file_contexts" -o \
\) 2>/dev/null | head -n 1)


escape_regex() {
    echo "$1" | sed \
        -e 's/\./\\./g' \
        -e 's/\+/\\+/g' \
        -e 's/\[/\\[/g' \
        -e 's/\]/\\]/g' \
        -e 's/(/\\(/g' \
        -e 's/)/\\)/g' \
        -e 's/\^/\\^/g' \
        -e 's/\$/\\$/g' \
        -e 's/?/\\?/g'
}


append_context() {
    local path="$1"
    local ctx="$2"
    local isdir="$3"
    local esc=$(escape_regex "$path")
    local line="/${esc} ${ctx}"

    grep -qxF "$line" "$FILE_CONTEXTS" 2>/dev/null || \
        echo "$line" >> "$FILE_CONTEXTS"
}


find_context() {
    local full="$1"
    local ctx="u:object_r:system_file:s0"

    if [ -f "$FC_SOURCE" ]; then

        while read -r line; do

            rule=$(echo "$line" | awk '{print $1}')
            se=$(echo "$line" | awk '{print $2}')

            [ -z "$rule" ] && continue
            [ -z "$se" ] && continue

            if echo "$full" | grep -Pq "^${rule}$"; then
                ctx="$se"
            fi

        done < "$FC_SOURCE"
    fi

    echo "$ctx"
}


GENERATE_FS_CONFIG() {
    echo "- Generating fs_config"

    > "$FS_CONFIG"

    echo "/ 0 0 0755" >> "$FS_CONFIG"
	echo "${IMG_NAME_BASE}/ 0 0 0755" >> "$FS_CONFIG"

    find "$SRC_MOUNT" -mindepth 1 -print0 | while IFS= read -r -d '' f; do

        rel="${f#$SRC_MOUNT}"
        rel="${rel#/}"
        path="${IMG_NAME_BASE}/${rel}"
        uid=$(stat -c %u "$f")
        gid=$(stat -c %g "$f")
        mode="0$(stat -c %a "$f")"

        echo "$path $uid $gid $mode" >> "$FS_CONFIG"

    done

    sort -u "$FS_CONFIG" -o "$FS_CONFIG"
}


GENERATE_FILE_CONTEXTS() {
    echo "- Generating file_contexts"

    > "$FILE_CONTEXTS"

    ROOT_CONTEXT="u:object_r:system_file:s0"

    if [ -f "$FC_SOURCE" ]; then
        ROOT_CONTEXT=$(find_context "/${IMG_NAME_BASE}")
    fi

    append_context "${IMG_NAME_BASE}" "$ROOT_CONTEXT" 1

    find "$SRC_MOUNT" -mindepth 1 -print0 | while IFS= read -r -d '' f; do

        rel="${f#$SRC_MOUNT}"
        rel="${rel#/}"

        ctx=$(getfattr -n security.selinux \
            --only-values "$f" 2>/dev/null | tr -d '\0')

        [ -z "$ctx" ] && \
            ctx="u:object_r:system_file:s0"

        if [[ "$rel" == *"lost+found"* ]]; then
            ctx="u:object_r:rootfs:s0"
        fi

        if [ -d "$f" ]; then
            append_context "${IMG_NAME_BASE}/${rel}" "$ctx" 1
        else
            append_context "${IMG_NAME_BASE}/${rel}" "$ctx" 0
        fi

    done

    sort -u "$FILE_CONTEXTS" -o "$FILE_CONTEXTS"
}


GENERATE_FS_CONFIG
GENERATE_FILE_CONTEXTS

echo "- Extracting ${IMG_NAME_BASE}"
cp -ar "$SRC_MOUNT"/* "${FIRM_DIR}/$IMG_NAME_BASE"

# umount and delete mounted folder
umount "$SRC_MOUNT" 2>/dev/null || true
rm -rf "$SRC_MOUNT"