#!/bin/bash

# Alt g — open a GitHub PR for review in a dedicated tab: pick a source repo,
# fzf one of its open PRs, check that PR out as a wcheckout worktree, then open a
# 30% opencode pane that boots into "/review-pr <N>" beside a 70% nvim pane, both
# rooted in the worktree. The pure picker/parse/render helpers live in
# utils/utility.sh (unit-tested in tests/test_pr_review_layout.zsh); the wcheckout
# checkout is owned here.
#
# The PR title/body/author come from `gh` and are untrusted data — they are only
# ever shown in the fzf list, never executed. Only the PR *number* (digits,
# validated) is interpolated into the layout and git refs.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Append "-N" to $1 until it names a path that does not exist. Mirrors the
# worktree tooling's resolve_unique_dir, reimplemented here because that lives in
# a zsh-only module (worktree_core.sh) this bash launcher cannot source.
_resolve_unique_dir() {
	local base_dir="$1"
	if [[ ! -d "$base_dir" ]]; then
		printf '%s' "$base_dir"
		return 0
	fi
	local suffix=1
	while [[ -d "${base_dir}-${suffix}" ]]; do
		suffix=$((suffix + 1))
	done
	printf '%s' "${base_dir}-${suffix}"
}

# Print the path of an existing git worktree of $repo_dir already checked out on
# refs/heads/$branch (or nothing). Lets a re-review reuse the same wcheckout
# worktree instead of stacking a "<folder>-1" duplicate.
_worktree_path_for_branch() {
	local repo_dir="$1" branch="$2"
	git -C "$repo_dir" worktree list --porcelain 2>/dev/null | awk -v b="refs/heads/$branch" '
		/^worktree / { p = substr($0, 10) }
		/^branch /   { if ($2 == b) { print p; exit } }
	'
}

# Check the PR out as a wcheckout worktree and print its absolute path on stdout.
# Args: <repo_dir> <pr_number> <head_ref> <base_ref> <is_fork>. Reuses an
# existing worktree on the same branch; otherwise fetches the head ref (the PR
# ref for a fork) plus the base ref and adds a new worktree. All git/log chatter
# goes to stderr so stdout carries only the path.
prepare_pr_worktree() {
	local repo_dir="$1" pr_number="$2" head_ref="$3" base_ref="$4" is_fork="$5"
	local wcheckout_dir="${WCHECKOUT_DIR:-$HOME/Programming/wcheckout}"
	local local_branch folder

	if [[ "$is_fork" == "true" ]]; then
		# A fork's head branch isn't on origin; snapshot the PR ref into pr-<n>.
		local_branch="pr-${pr_number}"
		folder="pr-${pr_number}"
	else
		local_branch="$head_ref"
		folder="$(folder_name_from_branch "$head_ref")"
	fi

	local existing
	existing="$(_worktree_path_for_branch "$repo_dir" "$local_branch")"
	if [[ -n "$existing" && -d "$existing" ]]; then
		log_info "Reusing existing worktree at $existing"
		printf '%s' "$existing"
		return 0
	fi

	mkdir -p "$wcheckout_dir"

	# Make the head ref available locally (fork: a pr-<n> snapshot branch).
	if [[ "$is_fork" == "true" ]]; then
		git -C "$repo_dir" fetch origin "pull/${pr_number}/head:${local_branch}" >&2 || return 1
	else
		git -C "$repo_dir" fetch origin "$head_ref" >&2 || return 1
	fi
	# Refresh the base ref too so the in-worktree diff is accurate; non-fatal.
	if [[ -n "$base_ref" && "$base_ref" != "null" ]]; then
		git -C "$repo_dir" fetch origin "$base_ref" >/dev/null 2>&1 || true
	fi

	local worktree_path
	worktree_path="$(_resolve_unique_dir "$wcheckout_dir/$folder")"

	if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$local_branch"; then
		git -C "$repo_dir" worktree add "$worktree_path" "$local_branch" >&2 || return 1
	else
		git -C "$repo_dir" worktree add "$worktree_path" -b "$local_branch" "origin/$head_ref" >&2 || return 1
	fi

	printf '%s' "$worktree_path"
}

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf nvim opencode gh git jq || exit 1

	# 1. Pick the source repo (a real clone under ~/Programming/<org>/<repo>).
	local repo_dir
	repo_dir="$(select_source_repo_dir)" || exit 0
	[[ -z "$repo_dir" ]] && exit 0

	# 2. Resolve the GitHub slug so every gh call targets it explicitly.
	local repo_slug
	if ! repo_slug="$(cd "$repo_dir" && gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null)" || [[ -z "$repo_slug" ]]; then
		log_error "Could not resolve a GitHub repo for $repo_dir"
		exit 1
	fi

	# 3. List open PRs and pick one. Title/author are untrusted display data.
	local pr_rows
	if ! pr_rows="$(gh pr list --repo "$repo_slug" --state open --limit 100 --json number,title,author --jq '.[] | "#\(.number)  \(.title)  (\(.author.login))"' 2>/dev/null)"; then
		log_error "Failed to list PRs for $repo_slug (is gh authenticated?)"
		exit 1
	fi
	[[ -z "$pr_rows" ]] && { log_info "No open PRs in $repo_slug"; exit 0; }

	local selection
	selection="$(printf '%s\n' "$pr_rows" | fzf --prompt="Select PR to review: ")" || exit 0
	[[ -z "$selection" ]] && exit 0

	local pr_number
	pr_number="$(pr_number_from_selection "$selection")" || { log_error "Could not parse a PR number from: $selection"; exit 1; }

	# 4. Fetch the metadata the checkout needs (head/base branch, fork flag).
	local meta head_ref base_ref is_fork
	if ! meta="$(gh pr view "$pr_number" --repo "$repo_slug" --json headRefName,baseRefName,isCrossRepository 2>/dev/null)"; then
		log_error "Failed to read PR #$pr_number from $repo_slug"
		exit 1
	fi
	head_ref="$(printf '%s' "$meta" | jq -r '.headRefName')"
	base_ref="$(printf '%s' "$meta" | jq -r '.baseRefName')"
	is_fork="$(printf '%s' "$meta" | jq -r '.isCrossRepository')"
	[[ -z "$head_ref" || "$head_ref" == "null" ]] && { log_error "PR #$pr_number has no head branch"; exit 1; }

	# 5. Check the PR out as a wcheckout worktree (reusing one if it exists).
	local worktree_path
	worktree_path="$(prepare_pr_worktree "$repo_dir" "$pr_number" "$head_ref" "$base_ref" "$is_fork")" \
		|| { log_error "Failed to prepare a worktree for PR #$pr_number"; exit 1; }
	[[ -z "$worktree_path" || ! -d "$worktree_path" ]] && { log_error "Worktree path did not resolve for PR #$pr_number"; exit 1; }

	# 6. Open the review layout (opencode boots into /review-pr <N> on the left,
	#    nvim on the right) in a new tab rooted in the worktree, then reindex tabs.
	local layout
	layout="$(render_pr_review_layout "$pr_number")" || { log_error "Failed to render the PR-review layout"; exit 1; }
	local tab_id
	tab_id="$(zellij action new-tab --cwd "$worktree_path" --layout "$layout")"
	sleep 0.2
	rm -rf "$(dirname "$layout")"
	if [[ "$tab_id" =~ ^[0-9]+$ ]]; then
		zellij action rename-tab --tab-id "$tab_id" "$(basename "$worktree_path")"
	else
		zellij action rename-tab "$(basename "$worktree_path")"
	fi

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
