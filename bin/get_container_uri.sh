#!/bin/bash
# Usage: get_container_uri.sh <tool> [version]

set -uo pipefail

TOOL="${1:-}"
VERSION="${2:-}"
SCRIPT_DIR="$(dirname "$0")"

if [ -z "$TOOL" ]; then
  echo "Usage: $0 <tool> [version]" >&2
  exit 1
fi

BIOCONTAINERS_API="https://api.biocontainers.pro/ga4gh/trs/v2/tools"
QUAY_API="https://quay.io/api/v1/repository/biocontainers"
DOCKERHUB_API="https://hub.docker.com/v2/repositories/biocontainers"

try_biocontainers() {
  local RESPONSE
  RESPONSE=$(curl -sf "${BIOCONTAINERS_API}/${TOOL}/versions") || return 1
  [ -n "$RESPONSE" ] || return 1
  echo "$RESPONSE" | grep -q '"detail"' && return 1
  echo "$RESPONSE" | python3 "${SCRIPT_DIR}/parse_biocontainer.py" \
    --source biocontainers "${VERSION}"
}

try_quay() {
  local RESPONSE
  RESPONSE=$(curl -sf "${QUAY_API}/${TOOL}/tag/?limit=100&onlyActiveTags=true") || return 1
  [ -n "$RESPONSE" ] || return 1
  echo "$RESPONSE" | grep -q '"error_message"' && return 1
  echo "$RESPONSE" | python3 "${SCRIPT_DIR}/parse_biocontainer.py" \
    --source quay --tool "${TOOL}" "${VERSION}"
}

try_dockerhub() {
  local RESPONSE
  RESPONSE=$(curl -sf "${DOCKERHUB_API}/${TOOL}/tags/?page_size=100") || return 1
  [ -n "$RESPONSE" ] || return 1
  echo "$RESPONSE" | python3 "${SCRIPT_DIR}/parse_biocontainer.py" \
    --source dockerhub --tool "${TOOL}" "${VERSION}"
}

# --- Main: try each source in order, suppress per-source stderr ---
URI=""

if URI=$(try_biocontainers 2>/dev/null); then
  echo "$URI"; exit 0
fi
echo "[WARN] BioContainers API: no result for '${TOOL}', trying quay.io..." >&2

if URI=$(try_quay 2>/dev/null); then
  echo "$URI"; exit 0
fi
echo "[WARN] quay.io: no result for '${TOOL}', trying Docker Hub..." >&2

if URI=$(try_dockerhub 2>/dev/null); then
  echo "$URI"; exit 0
fi

echo "Error: '${TOOL}' not found in BioContainers API, quay.io, or Docker Hub" >&2
exit 1
