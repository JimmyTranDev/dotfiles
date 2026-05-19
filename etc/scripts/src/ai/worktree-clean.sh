#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

get_pr_state() {
	local branch="$1"
	local state
	state=$(gh pr view "$branch" --json state -q '.state' 2>/dev/null || echo "NONE")
	echo "$state"
}

is_stale_by_date() {
	local last_date="$1"
	local threshold_days=14
	local last_epoch
	last_epoch=$(date -j -f "%Y-%m-%d" "$last_date" "+%s" 2>/dev/null || date -d "$last_date" "+%s" 2>/dev/null || echo "0")
	local now_epoch
	now_epoch=$(date "+%s")
	local diff_days=$(((now_epoch - last_epoch) / 86400))
	[[ "$diff_days" -ge "$threshold_days" ]]
}

scan_worktrees() {
	local worktree_root="$1"
	local dry_run="$2"

	if [[ ! -d "$worktree_root" ]]; then
		log_error "Worktree root does not exist: $worktree_root"
		json_output "$(json_obj_raw \
			"worktree_root" "$(json_escape "$worktree_root")" \
			"total" "0" \
			"cleaned" "0" \
			"stale" "[]" \
			"active" "[]")"
		return 0
	fi

	local stale_arr=()
	local active_arr=()
	local total=0
	local cleaned=0

	for entry in "$worktree_root"/*/; do
		[[ ! -d "$entry" ]] && continue
		[[ ! -f "$entry/.git" ]] && continue
		total=$((total + 1))

		local path="${entry%/}"
		local branch
		branch=$(git -C "$path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

		local last_commit_date
		last_commit_date=$(git -C "$path" log -1 --format="%ad" --date=short 2>/dev/null || echo "1970-01-01")

		local pr_state
		pr_state=$(get_pr_state "$branch")

		local is_merged=false
		if [[ "$pr_state" == "MERGED" || "$pr_state" == "CLOSED" ]]; then
			is_merged=true
		fi

		local is_stale=false
		if [[ "$is_merged" == "true" ]] || is_stale_by_date "$last_commit_date"; then
			is_stale=true
		fi

		if [[ "$is_stale" == "true" ]]; then
			local stale_obj
			stale_obj=$(json_obj_raw \
				"path" "$(json_escape "$path")" \
				"branch" "$(json_escape "$branch")" \
				"merged" "$is_merged" \
				"last_commit_date" "$(json_escape "$last_commit_date")" \
				"pr_status" "$(json_escape "$pr_state")")
			stale_arr+=("$stale_obj")

			if [[ "$dry_run" == "false" ]]; then
				log_info "Removing worktree: $path (branch: $branch)" >&2
				local main_repo
				main_repo=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null | sed 's|/.git$||' || echo "")
				if [[ -n "$main_repo" ]]; then
					git -C "$main_repo" worktree remove "$path" --force 2>/dev/null || rm -rf "$path"
					git -C "$main_repo" branch -D "$branch" 2>/dev/null || true
				else
					rm -rf "$path"
				fi
				cleaned=$((cleaned + 1))
			fi
		else
			local active_obj
			active_obj=$(json_obj_raw \
				"path" "$(json_escape "$path")" \
				"branch" "$(json_escape "$branch")" \
				"last_commit_date" "$(json_escape "$last_commit_date")")
			active_arr+=("$active_obj")
		fi
	done

	local stale_json
	stale_json=$(json_arr_raw "${stale_arr[@]}")

	local active_json
	active_json=$(json_arr_raw "${active_arr[@]}")

	local result
	result=$(json_obj_raw \
		"worktree_root" "$(json_escape "$worktree_root")" \
		"total" "$total" \
		"cleaned" "$cleaned" \
		"stale" "$stale_json" \
		"active" "$active_json")

	json_output "$result"
}

show_help() {
	cat <<'EOF' >&2
Usage: worktree-clean.sh [--dry-run] [--execute] [--dir <worktree-root>]

Scan and clean stale git worktrees as JSON.

Options:
  --dry-run              List stale worktrees without removing (default)
  --execute              Actually remove stale worktrees
  --dir <worktree-root>  Worktree root directory (default: ~/Programming/wcreated)
  --help                 Show this help message
EOF
}

main() {
	local worktree_root="$HOME/Programming/wcreated"
	local dry_run="true"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--dry-run)
			dry_run="true"
			shift
			;;
		--execute)
			dry_run="false"
			shift
			;;
		--dir)
			worktree_root="$2"
			shift 2
			;;
		*)
			shift
			;;
		esac
	done

	require_command "gh" "brew install gh"
	scan_worktrees "$worktree_root" "$dry_run"
}

main "$@"
