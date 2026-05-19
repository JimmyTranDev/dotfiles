#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

get_branch_info() {
	local dir="${1:-.}"

	if ! git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
		log_error "Not a git repository: $dir"
		return 1
	fi

	local current_branch
	current_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

	local base_branch
	base_branch=$(find_base_branch "$dir")

	local ahead=0
	local behind=0
	if [[ "$base_branch" != "unknown" ]] && [[ "$current_branch" != "detached" ]]; then
		ahead=$(git -C "$dir" rev-list --count "$base_branch..$current_branch" 2>/dev/null || echo "0")
		behind=$(git -C "$dir" rev-list --count "$current_branch..$base_branch" 2>/dev/null || echo "0")
	fi

	local uncommitted
	uncommitted=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

	local staged
	staged=$(git -C "$dir" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

	local diff_stat=""
	if [[ "$base_branch" != "unknown" ]] && [[ "$current_branch" != "detached" ]]; then
		diff_stat=$(git -C "$dir" diff --stat "$base_branch...$current_branch" 2>/dev/null | tail -1 || echo "")
	fi

	json_output "$(json_obj_raw \
		"current_branch" "$(json_escape "$current_branch")" \
		"base_branch" "$(json_escape "$base_branch")" \
		"ahead" "$ahead" \
		"behind" "$behind" \
		"uncommitted" "$uncommitted" \
		"staged" "$staged" \
		"diff_stat" "$(json_escape "$diff_stat")")"
}

show_help() {
	log_info "Usage: git-branch-info.sh [directory]"
	log_info ""
	log_info "Output git branch context as JSON."
	log_info ""
	log_info "Options:"
	log_info "  --help    Show this help message"
}

main() {
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	get_branch_info "$dir"
}

main "$@"
