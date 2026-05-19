#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

create_pr() {
	local branch="$1"
	local title="$2"
	local body="$3"
	local base="$4"
	local draft="$5"

	if [[ -z "$base" ]]; then
		base=$(find_base_branch)
		log_info "Auto-detected base branch: $base"
	fi

	local worktree_path="$WORKTREE_ROOT/$branch"

	if [[ ! -d "$WORKTREE_ROOT" ]]; then
		mkdir -p "$WORKTREE_ROOT"
		log_info "Created worktree root: $WORKTREE_ROOT"
	fi

	if [[ -d "$worktree_path" ]]; then
		log_info "Worktree already exists: $worktree_path"
	else
		log_info "Creating worktree: $worktree_path"
		git worktree add "$worktree_path" -b "$branch"
	fi

	log_info "Pushing branch: $branch"
	git -C "$worktree_path" push -u origin "$branch" 2>&1 >&2

	local gh_args=(pr create --head "$branch" --base "$base" --title "$title" --body "$body")
	if [[ "$draft" == "true" ]]; then
		gh_args+=(--draft)
	fi

	log_info "Creating PR..."
	local pr_url
	pr_url=$(gh "${gh_args[@]}" 2>/dev/null)

	local pr_json
	pr_json=$(gh pr view "$branch" --json number,url 2>/dev/null)

	local pr_number
	pr_number=$(echo "$pr_json" | jq -r '.number')
	pr_url=$(echo "$pr_json" | jq -r '.url')

	json_output "$(json_obj_raw \
		"pr_number" "$pr_number" \
		"pr_url" "$(json_escape "$pr_url")" \
		"branch" "$(json_escape "$branch")" \
		"base_branch" "$(json_escape "$base")" \
		"worktree_path" "$(json_escape "$worktree_path")")"
}

show_help() {
	echo "Usage: pr-create.sh --branch <name> --title <title> --body <body> [--base <branch>] [--draft]" >&2
	echo "" >&2
	echo "Create a PR with worktree setup." >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --branch <name>   Branch name (required)" >&2
	echo "  --title <title>   PR title (required)" >&2
	echo "  --body <body>     PR body (required)" >&2
	echo "  --base <branch>   Base branch (auto-detected if omitted)" >&2
	echo "  --draft           Create as draft PR" >&2
	echo "  --help            Show this help message" >&2
}

main() {
	local branch=""
	local title=""
	local body=""
	local base=""
	local draft="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--branch)
			branch="$2"
			shift 2
			;;
		--title)
			title="$2"
			shift 2
			;;
		--body)
			body="$2"
			shift 2
			;;
		--base)
			base="$2"
			shift 2
			;;
		--draft)
			draft="true"
			shift
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

	if [[ -z "$branch" ]] || [[ -z "$title" ]] || [[ -z "$body" ]]; then
		log_error "Missing required arguments: --branch, --title, --body"
		show_help
		exit 1
	fi

	require_command "gh" "brew install gh"
	create_pr "$branch" "$title" "$body" "$base" "$draft"
}

main "$@"
