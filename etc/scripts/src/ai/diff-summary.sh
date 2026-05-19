#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

build_commits_json() {
	local dir="$1"
	local base="$2"
	local current="$3"

	local commits_arr=()
	while IFS='|' read -r hash author date message; do
		[[ -z "$hash" ]] && continue
		local obj
		obj=$(json_obj "hash" "$hash" "author" "$author" "date" "$date" "message" "$message")
		commits_arr+=("$obj")
	done < <(git -C "$dir" log --pretty=format:"%H|%an|%ad|%s" --date=short "$base..$current" 2>/dev/null || true)

	json_arr_raw "${commits_arr[@]}"
}

build_files_json() {
	local dir="$1"
	local base="$2"
	local current="$3"

	local -A status_map
	while IFS=$'\t' read -r status path; do
		[[ -z "$path" ]] && continue
		status_map["$path"]="$status"
	done < <(git -C "$dir" diff --name-status "$base...$current" 2>/dev/null || true)

	local files_arr=()
	while IFS=$'\t' read -r ins del path; do
		[[ -z "$path" ]] && continue
		local status="${status_map[$path]:-M}"
		ins="${ins//-/0}"
		del="${del//-/0}"
		local obj
		obj=$(json_obj_raw "path" "$(json_escape "$path")" "status" "$(json_escape "$status")" "insertions" "$ins" "deletions" "$del")
		files_arr+=("$obj")
	done < <(git -C "$dir" diff --numstat "$base...$current" 2>/dev/null || true)

	json_arr_raw "${files_arr[@]}"
}

generate_diff_summary() {
	local dir="$1"
	local base="$2"

	require_git_repo "$dir"

	local current
	current=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

	if [[ -z "$base" ]]; then
		base=$(find_base_branch "$dir")
		if [[ "$base" == "unknown" ]]; then
			log_error "Could not detect base branch"
			return 1
		fi
	fi

	log_info "Diffing $current against $base" >&2

	local total_ins=0 total_del=0 files_changed=0
	while IFS=$'\t' read -r ins del _path; do
		[[ -z "$_path" ]] && continue
		ins="${ins//-/0}"
		del="${del//-/0}"
		total_ins=$((total_ins + ins))
		total_del=$((total_del + del))
		files_changed=$((files_changed + 1))
	done < <(git -C "$dir" diff --numstat "$base...$current" 2>/dev/null || true)

	local commit_count
	commit_count=$(git -C "$dir" rev-list --count "$base..$current" 2>/dev/null || echo "0")

	local commits_json
	commits_json=$(build_commits_json "$dir" "$base" "$current")

	local files_json
	files_json=$(build_files_json "$dir" "$base" "$current")

	local result
	result=$(json_obj_raw \
		"base_branch" "$(json_escape "$base")" \
		"files_changed" "$files_changed" \
		"insertions" "$total_ins" \
		"deletions" "$total_del" \
		"commit_count" "$commit_count" \
		"commits" "$commits_json" \
		"files" "$files_json")

	json_output "$result"
}

show_help() {
	echo "Usage: diff-summary.sh [--base <branch>] [directory]"
	echo ""
	echo "Structured diff summary against base branch as JSON."
	echo ""
	echo "Options:"
	echo "  --base <branch>  Base branch to diff against (auto-detected if omitted)"
	echo "  --help           Show this help message"
}

main() {
	local dir="."
	local base=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--base)
			base="$2"
			shift 2
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	generate_diff_summary "$dir" "$base"
}

main "$@"
