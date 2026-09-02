#!/bin/bash

DOWNLOAD_GITHUB_FOLDER() {

    local URL="$1"
    local OUT="${2:-}"

    if [ -z "$URL" ]; then
        echo "Usage: DOWNLOAD_GITHUB_FOLDER <GitHub_Folder_URL> [OUTPUT]"
        return 1
    fi

    local REPO BRANCH FOLDER

    read -r REPO BRANCH FOLDER <<< "$(
        printf '%s\n' "$URL" |
        sed -E 's#https://github\.com/([^/]+/[^/]+)/tree/([^/]+)/?(.*)#\1 \2 \3#'
    )"

    if [ -z "$REPO" ] || [ -z "$BRANCH" ] || [ -z "$FOLDER" ]; then
        echo "Invalid GitHub folder URL!"
        return 1
    fi

    FOLDER="${FOLDER#/}"
    FOLDER="${FOLDER%/}"

    [ -z "$OUT" ] && OUT="${FOLDER##*/}"
    [ -z "$OUT" ] && OUT="${REPO##*/}"

    echo
    echo "=========================================="
    echo "       GitHub Folder Downloader"
    echo "=========================================="
    echo "GitHub Repo : $REPO"
    echo "Branch      : $BRANCH"
    echo "Folder      : $FOLDER"
    echo "Out Dir     : $OUT"
    echo "=========================================="
    echo
    echo "Starting download..."
    echo

    DOWNLOAD_GITHUB_FOLDER_INTERNAL() {

        local CURRENT_FOLDER="$1"
        local CURRENT_OUT="$2"

        local API
        API="https://api.github.com/repos/$REPO/contents/$CURRENT_FOLDER?ref=$BRANCH"

        local RESPONSE

        RESPONSE="$(curl -fsSL \
            -H "Accept: application/vnd.github+json" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "$API")" || {
            echo "Error: GitHub folder not found: $CURRENT_FOLDER"
            return 1
        }

        if ! jq -e 'type == "array"' >/dev/null <<< "$RESPONSE"; then
            echo "Error: GitHub folder not found: $CURRENT_FOLDER"
            return 1
        fi

        mkdir -p "$CURRENT_OUT"

        printf '%s\n' "$RESPONSE" |
        jq -c '.[]' |
        while read -r ITEM; do

            local NAME TYPE DOWNLOAD_URL

            NAME="$(jq -r '.name' <<< "$ITEM")"
            TYPE="$(jq -r '.type' <<< "$ITEM")"

            if [ "$TYPE" = "file" ]; then

                DOWNLOAD_URL="$(jq -r '.download_url' <<< "$ITEM")"

                printf "Downloading %-40s ... " "$NAME"

                curl -fsSL \
                    "$DOWNLOAD_URL" \
                    -o "$CURRENT_OUT/$NAME" && echo "100%" || {
                    echo "FAILED"
                    continue
                }

            elif [ "$TYPE" = "dir" ]; then

                DOWNLOAD_GITHUB_FOLDER_INTERNAL \
                    "$CURRENT_FOLDER/$NAME" \
                    "$CURRENT_OUT/$NAME" || return 1

            fi

        done
    }

    DOWNLOAD_GITHUB_FOLDER_INTERNAL "$FOLDER" "$OUT" || return 1

    echo
    echo "✓ Download completed"
}
