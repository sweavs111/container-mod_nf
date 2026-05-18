#!/usr/bin/env python3
# Usage: curl ... | python3 parse_biocontainer.py [version] [--source biocontainers|quay|dockerhub] [--tool TOOL]

import sys
import json
import re
import argparse


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


def parse_biocontainers(data, version_filter):
    candidates = []
    for entry in data:
        for img in entry.get("images", []):
            if img.get("image_type") != "Docker":
                continue
            image_name = img.get("image_name", "")
            version = image_name.split(":")[-1] if ":" in image_name else ""
            if version_filter and not version.startswith(version_filter):
                continue
            candidates.append((version, image_name))
    return candidates


def parse_quay(data, tool, version_filter):
    candidates = []
    for tag in data.get("tags", []):
        tag_name = tag.get("name", "")
        if not tag_name:
            continue
        if version_filter and not tag_name.startswith(version_filter):
            continue
        image_name = f"quay.io/biocontainers/{tool}:{tag_name}"
        candidates.append((tag_name, image_name))
    return candidates


def parse_dockerhub(data, tool, version_filter):
    candidates = []
    for result in data.get("results", []):
        tag_name = result.get("name", "")
        if not tag_name:
            continue
        if version_filter and not tag_name.startswith(version_filter):
            continue
        image_name = f"biocontainers/{tool}:{tag_name}"
        candidates.append((tag_name, image_name))
    return candidates


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("version", nargs="?", default="")
    parser.add_argument("--source", choices=["biocontainers", "quay", "dockerhub"], default="biocontainers")
    parser.add_argument("--tool", default="")
    args = parser.parse_args()

    data = json.load(sys.stdin)

    if args.source == "quay":
        if not args.tool:
            print("Error: --tool required with --source quay", file=sys.stderr)
            sys.exit(1)
        candidates = parse_quay(data, args.tool, args.version)
    elif args.source == "dockerhub":
        if not args.tool:
            print("Error: --tool required with --source dockerhub", file=sys.stderr)
            sys.exit(1)
        candidates = parse_dockerhub(data, args.tool, args.version)
    else:
        candidates = parse_biocontainers(data, args.version)

    if not candidates:
        print("Error: no matching version found", file=sys.stderr)
        sys.exit(1)

    candidates.sort(key=parse_version, reverse=True)
    _, image_name = candidates[0]
    print("docker://" + image_name)


if __name__ == "__main__":
    main()
