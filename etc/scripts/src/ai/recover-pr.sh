#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

get_branch_from_worktree() {
	local worktree_path="$1"
	local git_file="$worktree_path/.git"

	if [[ -f "$git_file" ]]; then
		local git_dir
		git_dir=$(sed 's/gitdir: //' "$git_file")
		local head_file
		if [[ "$git_dir" = /* ]]; then
			head_file="$git_dir/HEAD"
		else
			head_file="$worktree_path/$git_dir/HEAD"
		fi
		if [[ -f "$head_file" ]]; then
			local ref
			ref=$(cat "$head_file")
			if [[ "$ref" == ref:* ]]; then
				echo "${ref#ref: refs/heads/}"
			else
				echo "detached"
			fi
			return 0
		fi
	elif [[ -d "$worktree_path/.git" ]]; then
		git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached"
		return 0
	fi

	echo "unknown"
}

recover_worktrees() {
	local worktree_root="$1"

	if [[ ! -d "$worktree_root" ]]; then
		log_error "Worktree root does not exist: $worktree_root"
		json_output "$(json_obj_raw \
			"worktree_root" "$(json_escape "$worktree_root")" \
			"recoverable" "[]" \
			"orphaned" "[]")"
		return 0
	fi

	local recoverable_items=()
	local orphaned_items=()

	for dir in "$worktree_root"/*/; do
		[[ ! -d "$dir" ]] && continue
		dir="${dir%/}"
		local name="${dir##*/}"

		local branch
		branch=$(get_branch_from_worktree "$dir")

		if [[ "$branch" == "unknown" ]] || [[ "$branch" == "detached" ]]; then
			orphaned_items+=("$(json_obj "worktree_path" "$dir" "branch" "$branch")")
			log_info "Orphaned: $name (branch: $branch)"
			continue
		fi

		local pr_info
		pr_info=$(gh pr list --head "$branch" --json number,url,state -q '.[0]' 2>/dev/null || echo "")

		if [[ -n "$pr_info" ]] && [[ "$pr_info" != "null" ]]; then
			local pr_number
			pr_number=$(echo "$pr_info" | jq -r '.number')
			local pr_url
			pr_url=$(echo "$pr_info" | jq -r '.url')
			local pr_state
			pr_state=$(echo "$pr_info" | jq -r '.state')

			recoverable_items+=("$(json_obj_raw \
				"worktree_path" "$(json_escape "$dir")" \
				"branch" "$(json_escape "$branch")" \
				"pr_number" "$pr_number" \
				"pr_url" "$(json_escape "$pr_url")" \
				"pr_state" "$(json_escape "$pr_state")")")
			log_info "Recoverable: $name -> PR #$pr_number ($pr_state)"
		else
			orphaned_items+=("$(json_obj "worktree_path" "$dir" "branch" "$branch")")
			log_info "Orphaned: $name (branch: $branch)"
		fi
	done

	local recoverable_json
	recoverable_json=$(json_arr_raw "${recoverable_items[@]+"${recoverable_items[@]}"}")
	local orphaned_json
	orphaned_json=$(json_arr_raw "${orphaned_items[@]+"${orphaned_items[@]}"}")

	json_output "$(json_obj_raw \
		"worktree_root" "$(json_escape "$worktree_root")" \
		"recoverable" "$recoverable_json" \
		"orphaned" "$orphaned_json")"
}

show_help() {
	echo "Usage: recover-pr.sh [--dir <worktree-root>]" >&2
	echo "" >&2
	echo "Match orphaned worktrees to PRs." >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --dir <path>   Worktree root directory (default: ~/Programming/wcreated)" >&2
	echo "  --help         Show this help message" >&2
}

main() {
	local worktree_root="$WORKTREE_ROOT"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dir)
			worktree_root="$2"
			shift 2
			;;
		--help)
			show_help
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done

	require_command "gh" "brew install gh"
	recover_worktrees "$worktree_root"
}

main "$@"
