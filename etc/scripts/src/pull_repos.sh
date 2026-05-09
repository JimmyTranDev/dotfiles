#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/utility.sh"
source "$SCRIPT_DIR/../utils/logging.sh"

PROGRAMMING_DIR="${PROGRAMMING_DIR:-$HOME/Programming}"

pull_dir() {
	local target_dir="$1"
	local label="$2"

	if [[ ! -d "$target_dir" ]]; then
		log_warning "Skipping $label: $target_dir does not exist"
		return
	fi

	log_header "Pulling $label repos: $target_dir"

	for dir in "$target_dir"/*/; do
		if [[ -d "$dir" ]]; then
			if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
				log_warning "Skipping non-git directory: $dir"
				continue
			fi
			log_info "Pulling: $dir"
			git -C "$dir" pull --rebase || {
				log_error "Failed to pull changes in $dir"
				continue
			}
		fi
	done
}

main() {
	while IFS= read -r org_dir; do
		[[ ! -d "$org_dir" ]] && continue
		local org_name="${org_dir%/}"
		org_name="${org_name##*/}"
		pull_dir "${org_dir%/}" "$org_name"
	done < <(get_org_dirs "$PROGRAMMING_DIR")
}

main "$@"
