#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_INIT="$SDKMAN_DIR/bin/sdkman-init.sh"

main() {
	if [[ ! -f "$SDKMAN_INIT" ]]; then
		log_error "SDKMAN not found"
		exit 1
	fi

	source "$SDKMAN_INIT"

	local candidate="${1:-java}"
	local major_version="$2"

	if [[ -z "$major_version" ]]; then
		read -p "Enter $candidate major version (e.g. 21, 17, 11): " major_version
	fi

	if [[ -z "$major_version" ]]; then
		log_error "No version specified"
		exit 1
	fi

	log_info "Finding latest $candidate $major_version..."

	local versions
	versions=$(sdk list "$candidate" 2>/dev/null | grep -oE '\b'"$major_version"'\.[0-9]+[0-9.a-zA-Z_-]*-tem\b' | sort -uV | tail -1)

	if [[ -z "$versions" ]]; then
		versions=$(sdk list "$candidate" 2>/dev/null | grep -oE '\b'"$major_version"'\.[0-9]+[0-9.a-zA-Z_-]*\b' | sort -uV | tail -1)
	fi

	if [[ -z "$versions" ]]; then
		log_error "No $candidate version $major_version found"
		log_info "Try: sdk list $candidate"
		exit 1
	fi

	log_info "Installing $candidate $versions"
	sdk install "$candidate" "$versions"
}

main "$@"
