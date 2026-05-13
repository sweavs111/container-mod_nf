#!/usr/bin/env python3
# Usage: curl ... | python3 parse_biocontainer.py [version]

import sys
import json
import re

# Define sort order for package versions
def parse_version(candidate):
    version_string = candidate[0]  # e.g. "1.17--hd87286a_1" or "v1.7.0_cv3"

    # Old biocontainers tags use a "v" or "r" prefix (e.g. v1.7.0_cv3, r0.4.1)
    if version_string.startswith(("v", "r")):
        version_string = version_string[1:]

    # New format: strip build hash after "--" (e.g. "1.17--hd87286a_1" → "1.17")
    # Old format: strip _cvN build suffix (e.g. "1.7.0_cv3" → "1.7.0")
    clean_version = version_string.split("--")[0]
    clean_version = re.sub(r'_cv\d+$', '', clean_version)

    # Split into numeric parts and convert to integers for proper numeric sorting
    return [int(x) for x in re.split(r'[._-]', clean_version) if x.isdigit()]


def main():
    version_filter = sys.argv[1] if len(sys.argv) > 1 else ""

    # Read the biocontainer data from the API call
    data = json.load(sys.stdin)

    candidates = []

    # Loop through the biocontainer entries
    for entry in data:
        entry_id = entry.get("id", "")

        # If the entry isn't from docker, filter it out
        for img in entry.get("images", []):
            if img.get("image_type") != "Docker":
                continue

            image_name = img.get("image_name", "")
            # Extract version from image_name e.g. "quay.io/biocontainers/samtools:0.1.19--h94a8ba4_6"
            version = image_name.split(":")[-1] if ":" in image_name else ""

            # If the version isn't what the user requested, filter out. If no version was requested, everything passes
            if version_filter and not version.startswith(version_filter):
                continue
            
            # Append everything passing filters
            candidates.append((version, image_name))

    if not candidates:
        print("Error: no matching version found", file=sys.stderr)
        sys.exit(1)

    # Sort descending to get the latest build of the matching version
    candidates.sort(key=parse_version, reverse=True)
    _, image_name = candidates[0]
    print("docker://" + image_name)

if __name__ == "__main__":
    main()
