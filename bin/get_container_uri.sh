#!/bin/bash
# Usage: get_biocontainer_uri.sh <tool> [version]
# Example: get_biocontainer_uri.sh samtools
# Example: get_biocontainer_uri.sh samtools 1.17

set -euo pipefail

# --- Args ---
TOOL="${1:-}"
VERSION="${2:-}"
SCRIPT_DIR="$(dirname "$0")"

if [ -z "$TOOL" ]; then
  echo "Usage: $0 <tool> [version]" >&2
  exit 1
fi

API="https://api.biocontainers.pro/ga4gh/trs/v2/tools"

# --- Get biocontianer page ---

RESPONSE=$(curl -s "${API}/${TOOL}/versions")

if [ -z "$RESPONSE" ] || echo "$RESPONSE" | grep -q '"detail"'; then
  echo "Error: Tool '${TOOL}' not found in BioContainers" >&2
  exit 1
fi

# --- Parse versions ---

URI=$(echo "$RESPONSE" | python3 "${SCRIPT_DIR}/parse_biocontainer.py" "$VERSION")

if [ $? -ne 0 ]; then
  exit 1
fi

echo "$URI"
