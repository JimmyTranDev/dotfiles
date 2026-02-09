#!/bin/bash

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_INIT="$SDKMAN_DIR/bin/sdkman-init.sh"

if [[ ! -f "$SDKMAN_INIT" ]]; then
	echo "SDKMAN not found"
	exit 1
fi

source "$SDKMAN_INIT"

candidate="${1:-java}"
major_version="$2"

if [[ -z "$major_version" ]]; then
	read -p "Enter $candidate major version (e.g. 21, 17, 11): " major_version
fi

if [[ -z "$major_version" ]]; then
	echo "No version specified"
	exit 1
fi

echo "Finding latest $candidate $major_version..."

versions=$(sdk list "$candidate" 2>/dev/null | grep -oE '\b'"$major_version"'\.[0-9]+[0-9.a-zA-Z_-]*-tem\b' | sort -uV | tail -1)

if [[ -z "$versions" ]]; then
	versions=$(sdk list "$candidate" 2>/dev/null | grep -oE '\b'"$major_version"'\.[0-9]+[0-9.a-zA-Z_-]*\b' | sort -uV | tail -1)
fi

if [[ -z "$versions" ]]; then
	echo "No $candidate version $major_version found"
	echo "Try: sdk list $candidate"
	exit 1
fi

echo "Installing $candidate $versions"
sdk install "$candidate" "$versions"
