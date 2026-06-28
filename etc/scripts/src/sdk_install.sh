#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

SDKMAN_DIR="${SDKMAN_DIR:-$HOME/.sdkman}"
SDKMAN_INIT="$SDKMAN_DIR/bin/sdkman-init.sh"

# Extract installable version identifiers from `sdk list <candidate>` output read
# on stdin, deduped and newest-first. Two layouts exist: java and other vendored
# candidates render a `|`-delimited table whose last column is the install
# identifier (e.g. `21.0.5-tem`), while candidates like maven/gradle render plain
# whitespace-separated version columns. Parse the table column first, then fall
# back to grepping version-like tokens so both layouts work.
extract_versions() {
	local raw ids
	raw=$(cat)
	# awk exits 0 even when no row matches, so this stays safe under `set -e`.
	ids=$(printf '%s\n' "$raw" | awk -F'|' 'NF >= 6 { id = $NF; gsub(/[[:space:]]/, "", id); if (id ~ /^[0-9]/) print id }')
	if [[ -z "$ids" ]]; then
		# Non-table layout (maven, gradle, ...): grep the version tokens. `|| true`
		# keeps a no-match (grep exit 1) from tripping `set -e`.
		ids=$(printf '%s\n' "$raw" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?([._-][0-9A-Za-z]+)*') || true
	fi
	if [[ -z "$ids" ]]; then
		return 0
	fi
	printf '%s\n' "$ids" | sort -urV
}

# Original shortcut: `ji <candidate> <major>` installs the latest patch for that
# major (preferring Temurin) with no prompt and no fzf.
install_major() {
	local candidate="$1"
	local major_version="$2"

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

main() {
	if [[ ! -f "$SDKMAN_INIT" ]]; then
		log_error "SDKMAN not found"
		exit 1
	fi

	source "$SDKMAN_INIT"

	local candidate="${1:-java}"
	local major_version="$2"

	# An explicit major keeps the fast, unattended path.
	if [[ -n "$major_version" ]]; then
		install_major "$candidate" "$major_version"
		return
	fi

	if ! command -v fzf >/dev/null 2>&1; then
		log_error "fzf is required to pick a version (or pass a major, e.g. ji $candidate 21)"
		exit 1
	fi

	log_info "Loading available $candidate versions..."

	local versions
	versions=$(sdk list "$candidate" 2>/dev/null | extract_versions)

	if [[ -z "$versions" ]]; then
		log_error "No installable $candidate versions found"
		log_info "Try: sdk list $candidate"
		exit 1
	fi

	# `|| true`: fzf exits non-zero when cancelled (Esc); treat that as "no
	# selection" instead of letting `set -e` abort.
	local selected
	selected=$(printf '%s\n' "$versions" | fzf --prompt="Select $candidate version to install: ") || true
	[[ -z "$selected" ]] && exit 0

	log_info "Installing $candidate $selected"
	sdk install "$candidate" "$selected"
}

main "$@"
