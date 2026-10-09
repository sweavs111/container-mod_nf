#!/bin/bash
# patch_log_hook.sh — append a `source` of the shared load-logging hook
# (/usr/local/usrapps/brc/env/module_log.tcl) to a freshly-built module file.
# Called by the PATCH_LOG_HOOK Nextflow process with the full BUILD_CONTAINER result line.

set -uo pipefail

RESULT="${1:-}"
MOD_DIR="/usr/local/usrapps/brc/brc_modules/modules"

# Only process successful builds and already-existing containers.
# [ERR] lines mean no module file was written; skip silently.
case "$RESULT" in
    "[OK]"*|"[Already exists]"*) ;;
    *) exit 0 ;;
esac

# The URI is always the last whitespace-delimited token on the result line.
URI=$(echo "$RESULT" | awk '{print $NF}')

# Derive app name and clean version — mirrors container-mod's own parsing logic.
LAST=$(echo "$URI" | sed 's|.*//||' | awk -F'/' '{print $NF}')
APP=$(echo "$LAST" | cut -d':' -f1)
VER=$(echo "$LAST" | cut -d':' -f2 | sed -E 's/(--.*)?(_[0-9]+)?$//')

MODULE_FILE="$MOD_DIR/$APP/$VER"

if [ ! -f "$MODULE_FILE" ]; then
    echo "[WARN] patch_log_hook: module file not found: $MODULE_FILE"
    exit 0
fi

# Idempotency guard — don't append twice.
if grep -q "Log module load" "$MODULE_FILE"; then
    exit 0
fi

cat >> "$MODULE_FILE" << 'HOOK_EOF'

#-- Log module load (shared hook: edit /usr/local/usrapps/brc/env/module_log.tcl)
source "/usr/local/usrapps/brc/env/module_log.tcl"
HOOK_EOF

echo "[OK] patched log hook: $APP/$VER"
