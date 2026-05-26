#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

remove_spec() {
	local spec_file="$1"
	local plans_dir="$(dirname "$spec_file")"

	if [[ ! -f "$spec_file" ]]; then
		log_warning "Spec file not found: $spec_file"
		json_output "$(json_obj_raw "removed" "false" "reason" "$(json_escape "file not found")" "spec_file" "$(json_escape "$spec_file")")"
		return 0
	fi

	if git ls-files --error-unmatch "$spec_file" &>/dev/null; then
		log_info "Removing tracked spec file: $spec_file"
		git rm "$spec_file" 2>&1 >&2
	else
		log_info "Removing untracked spec file: $spec_file"
		rm "$spec_file"
	fi

	if [[ "$(ls -A "$plans_dir" 2>/dev/null)" == "" ]]; then
		log_info "Removing empty plans directory: $plans_dir"
		rmdir "$plans_dir" 2>/dev/null || true
	fi

	log_success "Spec file removed: $spec_file"
	json_output "$(json_obj_raw "removed" "true" "spec_file" "$(json_escape "$spec_file")")"
}

show_help() {
	echo "Usage: spec-cleanup.sh <file>" >&2
	echo "" >&2
	echo "Remove a consumed spec file after successful implementation." >&2
	echo "Handles git-tracked (git rm) and untracked (rm) files." >&2
	echo "Removes the plans/ directory if empty after deletion." >&2
	echo "" >&2
	echo "Arguments:" >&2
	echo "  <file>  Path to the spec file under plans/ (required)" >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --help  Show this help message" >&2
}

main() {
	local spec_file=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		-*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
		*)
			spec_file="$1"
			shift
			;;
		esac
	done

	if [[ -z "$spec_file" ]]; then
		log_error "Missing required argument: spec file path"
		show_help
		exit 1
	fi

	remove_spec "$spec_file"
}

main "$@"
