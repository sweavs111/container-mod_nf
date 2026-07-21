#!/bin/bash
# patch_log_hook.sh — append the load-logging TCL hook to a freshly-built module file.
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

#-- Log module load
if { [module-info mode load] } {
    catch {
        set _ts    [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%SZ} -gmt 1]
        set _user  $env(USER)
        set _group $env(GROUP)
        set _parts [split [module-info name] /]
        set _tool  [lindex $_parts 0]
        set _ver   [lindex $_parts 1]
        set _fh    [open "/usr/local/usrapps/brc/brc_modules/logs/module_loads.log" a]
        puts $_fh  "${_ts}|${_user}|${_group}|${_tool}|${_ver}"
        close $_fh
    }
}
HOOK_EOF

echo "[OK] patched log hook: $APP/$VER"
