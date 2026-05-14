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

# --- Exist function ---
check_exist() {
	local STRIP=$(echo $1 | sed 's|.*//||' | tr '/' '_')
	STRIP+=".sif"
	[ -f $IMAGE_PATH/$STRIP ]
}

# --- Download ---
if check_exist "$URI"; then
    echo "[Already exists]  $URI"
elif OUTPUT=$($CONTAINER_MOD pipe -t --profile "$MY_PROFILE" "$URI" 2>&1); then
    echo "[OK]  $URI"
else
    echo "[ERR] $URI -- $OUTPUT"
fi