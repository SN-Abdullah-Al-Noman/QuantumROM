#!/bin/bash

GIT_SPARSE_DOWNLOAD() {
    local REPO="$1"
    local BRANCH="$2"
    local FOLDER="$3"
    local OUT_DIR="$4"

    if [ -z "$REPO" ] || [ -z "$BRANCH" ] || [ -z "$FOLDER" ] || [ -z "$OUT_DIR" ]; then
        echo "Usage: GIT_DOWNLOAD <REPO> <BRANCH> <FOLDER> <OUT_DIR>"
        return 1
    fi

    OUT_DIR="$(realpath -m "$OUT_DIR")"

    echo
    echo "=========================================="
    echo "          Git Sparse Downloader"
    echo "=========================================="
    echo "Repo   : $REPO"
    echo "Branch : $BRANCH"
    echo "Folder : $FOLDER"
    echo "Output : $OUT_DIR"
    echo "=========================================="
    echo

    local TMP_DIR
    TMP_DIR="$(mktemp -d)" || {
        echo "Error: Failed to create temporary directory!"
        return 1
    }

    echo "Temporary directory:"
    echo "$TMP_DIR"
    echo

    git clone \
        --depth 1 \
        --filter=blob:none \
        --sparse \
        --branch "$BRANCH" \
        "https://github.com/$REPO.git" \
        "$TMP_DIR" || {
            echo "Error: Git clone failed!"
            rm -rf "$TMP_DIR"
            return 1
        }

    cd "$TMP_DIR" || {
        echo "Error: Failed to enter temporary directory!"
        rm -rf "$TMP_DIR"
        return 1
    }

    git sparse-checkout set "$FOLDER" || {
        echo "Error: Folder not found: $FOLDER"
        cd /
        rm -rf "$TMP_DIR"
        return 1
    }

    if [ ! -d "$TMP_DIR/$FOLDER" ]; then
        echo "Error: Folder not found: $FOLDER"
        cd /
        rm -rf "$TMP_DIR"
        return 1
    fi

    mkdir -p "$OUT_DIR" || {
        echo "Error: Failed to create output directory!"
        cd /
        rm -rf "$TMP_DIR"
        return 1
    }

    echo
    echo "Copying files..."
    echo

    cp -a "$TMP_DIR/$FOLDER/." "$OUT_DIR/" || {
        echo "Error: Failed to copy folder!"
        cd /
        rm -rf "$TMP_DIR"
        return 1
    }

    cd /

    rm -rf "$TMP_DIR"

    echo "✓ Download completed"
    echo "✓ Location: $OUT_DIR"
}
