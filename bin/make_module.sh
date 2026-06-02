#!/bin/bash
# -------------------------
# Download containers onto the BRC module space
# -------------------------

# --- load config ---
source ./config_mm.sh

# --- Environments ---
module load apptainer > /dev/null 2>&1

# --- Variables ---
URI="$1"
MY_PROFILE="$2"

# Source the profile to get profile-specific paths (e.g. IMG_OUTDIR)
source "$(dirname "$CONTAINER_MOD")/profiles/$MY_PROFILE"

# --- Pre-flight: verify container-mod metadata file exists ---
TOOL=$(echo "$URI" | sed 's|.*//||' | awk -F'/' '{print $NF}' | cut -d':' -f1)
METADATA_FILE="$(dirname "$CONTAINER_MOD")/repos/$TOOL"
if [ ! -f "$METADATA_FILE" ]; then
    echo "[ERR] $URI -- no container-mod metadata file found for '$TOOL'; expected at $METADATA_FILE. Create it manually before running the pipeline."
    exit 0
fi

# --- Exist function ---
check_exist() {
	local STRIP=$(echo $1 | sed 's|.*//||' | tr '/' '_')
	STRIP+=".sif"
	[ -f "$IMG_OUTDIR/$STRIP" ]
}

# --- Download ---
if check_exist "$URI"; then
    echo "[Already exists]  $URI"
elif OUTPUT=$($CONTAINER_MOD pipe -t --profile "$MY_PROFILE" --update "$URI" 2>&1); then
    echo "[OK]  $URI"
else
    # container-mod exited non-zero — verify the image landed anyway before declaring failure
    if check_exist "$URI"; then
        echo "[OK]  $URI"
    else
        echo "[ERR] $URI -- $OUTPUT"
    fi
fi
