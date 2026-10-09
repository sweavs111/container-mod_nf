#!/bin/bash
# migrate_log_hook.sh — one-time backfill: replace the inline load-logging
# TCL block that patch_log_hook.sh used to append to every module file with
# a `source` of the shared hook, so logging can be changed for every module
# in one place (/usr/local/usrapps/brc/env/module_log.tcl).
#
# Only files whose block matches the old inline hook byte-for-byte are
# changed; anything else is reported and left alone. Idempotent: files that
# already source the shared hook are skipped. The "#-- Log module load"
# marker is kept, so patch_log_hook.sh's idempotency guard still sees it.
#
# Usage: migrate_log_hook.sh [--dry-run] [MOD_DIR]
#   --dry-run   Show what would change (unified diff for the first file,
#               counts for all) without writing.
#   MOD_DIR     Defaults to /usr/local/usrapps/brc/brc_modules/modules
#
# Before a real run, back up MOD_DIR, e.g.
#   tar -czf modules_backup_$(date +%Y%m%d).tar.gz -C "$(dirname MOD_DIR)" modules

set -uo pipefail

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
    shift
fi

MOD_DIR="${1:-/usr/local/usrapps/brc/brc_modules/modules}"
SHARED_HOOK="/usr/local/usrapps/brc/env/module_log.tcl"
MARKER='#-- Log module load'

[[ -d "$MOD_DIR" ]] || { echo "[ERR] module directory not found: $MOD_DIR" >&2; exit 1; }
[[ -f "$SHARED_HOOK" ]] || { echo "[ERR] shared hook not found: $SHARED_HOOK" >&2; exit 1; }

# The exact block patch_log_hook.sh appended (from the marker to EOF).
OLD_BLOCK=$(cat <<'HOOK_EOF'
#-- Log module load
if { [module-info mode load] } {
    catch {
        set _ts    [clock format [clock seconds] -format {%Y-%m-%dT%H:%M:%S%z} -timezone :America/New_York]
        set _ts    [regsub {(\d\d)$} $_ts {:\1}]
        set _user  $env(USER)
        set _group $env(GROUP)
        set _parts [lrange [split [module-info name] /] end-1 end]
        set _tool  [lindex $_parts 0]
        set _ver   [lindex $_parts 1]
        set _fh    [open "/usr/local/usrapps/brc/brc_modules/logs/module_loads.log" a]
        puts $_fh  "${_ts}|${_user}|${_group}|${_tool}|${_ver}"
        close $_fh
    }
}
HOOK_EOF
)
NEW_BLOCK="${MARKER} (shared hook: edit ${SHARED_HOOK})
source \"${SHARED_HOOK}\""

migrated=0 already=0 no_hook=0 mismatch=0 failed=0 shown=0

while IFS= read -r -d '' module_file; do
    if grep -qF "source \"${SHARED_HOOK}\"" "$module_file"; then
        already=$((already + 1)); continue
    fi
    line=$(grep -nxF "$MARKER" "$module_file" | cut -d: -f1)
    if [[ -z "$line" ]]; then
        no_hook=$((no_hook + 1)); continue
    fi
    if [[ "$(tail -n "+$line" "$module_file")" != "$OLD_BLOCK" ]]; then
        echo "[WARN] logging block differs from the known inline hook, left alone: $module_file" >&2
        mismatch=$((mismatch + 1)); continue
    fi

    # $(...) drops trailing blank lines, so put back the one before the marker.
    new_content="$(head -n "$((line - 1))" "$module_file")

${NEW_BLOCK}"

    if [[ $DRY_RUN -eq 1 ]]; then
        if (( shown == 0 )); then
            echo "--- example: $module_file ---"
            diff -u "$module_file" <(printf '%s\n' "$new_content") || true
            shown=1
        fi
        migrated=$((migrated + 1)); continue
    fi

    # Atomic write via a sibling temp file, so a killed run can't leave a
    # half-written modulefile.
    tmpfile=$(mktemp "${module_file}.XXXXXX") || {
        echo "[ERR] failed to create temp file next to '$module_file'" >&2
        failed=$((failed + 1)); continue
    }
    if printf '%s\n' "$new_content" > "$tmpfile" && chmod 644 "$tmpfile" && mv "$tmpfile" "$module_file"; then
        migrated=$((migrated + 1))
    else
        rm -f "$tmpfile"
        echo "[ERR] failed to write: $module_file" >&2
        failed=$((failed + 1))
    fi
done < <(find "$MOD_DIR" -mindepth 2 -maxdepth 2 -type f -print0)

echo
(( DRY_RUN )) && echo -n "[DRY RUN] would migrate" || echo -n "migrated"
echo ": $migrated   already shared: $already   no hook: $no_hook   unknown block: $mismatch   failed: $failed"
(( failed == 0 ))
