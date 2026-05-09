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
	local candidate_dir="$SDKMAN_DIR/candidates/$candidate"

	if [[ ! -d "$candidate_dir" ]]; then
		log_error "No $candidate versions installed"
		exit 1
	fi

	local versions=()
	local current=""
	if [[ -L "$candidate_dir/current" ]]; then
		current=$(basename "$(readlink "$candidate_dir/current")")
	fi

	for dir in "$candidate_dir"/*/; do
		[[ -d "$dir" ]] || continue
		local version
		version=$(basename "$dir")
		[[ "$version" == "current" ]] && continue
		versions+=("$version")
	done

	if [[ ${#versions[@]} -eq 0 ]]; then
		log_error "No $candidate versions installed"
		exit 1
	fi

	local sorted=()
	while IFS= read -r line; do
		[[ -n "$line" ]] && sorted+=("$line")
	done < <(printf "%s\n" "${versions[@]}" | sort -rV)

	local display=()
	for v in "${sorted[@]}"; do
		if [[ "$v" == "$current" ]]; then
			display+=("$v *")
		else
			display+=("$v")
		fi
	done

	local selected
	selected=$(printf "%s\n" "${display[@]}" | fzf --prompt="Select $candidate version: ")
	[[ -z "$selected" ]] && exit 0

	selected="${selected% \*}"
	sdk use "$candidate" "$selected"
}

main "$@"
