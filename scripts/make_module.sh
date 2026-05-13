#!/bin/bash
# -------------------------
# Initial download of containers onto the BRC module space 
# -------------------------

# --- load config ---
source config_cm.sh

# --- Environments ---
module load apptainer

# -- Set up logs ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="${LOG_PATH}_${TIMESTAMP}"
mkdir -p "$LOG_DIR"
touch ${LOG_DIR}/error.log
touch ${LOG_DIR}/success.log

# --- Export variables ---
export CONTAINER_MOD MY_PROFILE LOG_DIR IMAGE_PATH

# --- Exist function ---
check_exist() {
	local STRIP=$(echo $1 | sed 's|.*//||' | tr '/' '_')
	STRIP+=".sif"
	[ -f $IMAGE_PATH/$STRIP ]
}

export -f check_exist


# --- Download function ---
download_container() {
    local URI="$1"
    
    if check_exist $URI; then
	echo "$URI -- Already exists" >> "${LOG_DIR}/success.log"
        echo "[Already exists]  $URI"
    else
    	if OUTPUT=$($CONTAINER_MOD pipe -t --profile "$MY_PROFILE" "$URI" 2>&1); then
        	echo "$URI" >> "${LOG_DIR}/success.log"
        	echo "[OK]  $URI"
    	else
        	echo "$URI" >> "${LOG_DIR}/error.log"
        	echo "[ERR] $URI"
        	echo "$OUTPUT" > "${LOG_DIR}/error_$(echo "$URI" | tr '/:' '__').txt"
    	fi
    fi
}

export -f download_container

# --- Execute ---
$PARALLEL --jobs 4 \
         --bar \
         --joblog "${LOG_DIR}/parallel.log" \
         download_container \
         :::: "$URI_LIST"

# --- Exit program ---
echo "=== DONE ==="
echo "Successes: $(wc -l < "${LOG_DIR}/success.log" 2>/dev/null || echo 0)"
echo "Errors:    $(wc -l < "${LOG_DIR}/error.log"   2>/dev/null || echo 0)"
