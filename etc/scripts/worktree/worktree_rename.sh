#!/bin/zsh
# worktree_rename.sh - Rename current worktree branch with custom name or JIRA ticket
# Usage: zsh worktree_rename.sh

set -e
autoload -U colors && colors

function require_tool() {
	if ! command -v "$1" &>/dev/null; then
		print -P "%F{red}Error: Required tool '$1' not found.%f"
		exit 1
	fi
}
require_tool git

current_branch=$(git rev-parse --abbrev-ref HEAD)
print -P "%F{cyan}Current branch: $current_branch%f"

jira_pattern='^[A-Z]+-[0-9]+'
if [[ "$current_branch" =~ $jira_pattern ]]; then
	require_tool jira
	print -P "%F{yellow}Branch already contains JIRA ticket: $jira_ticket%f"
	jira_ticket=$(echo "$current_branch" | grep -oE "$jira_pattern")
	print -P "%F{yellow}Fetching summary via jira CLI...%f"
	summary=$(jira issue view "$jira_ticket" --plain | grep '^Summary:' | sed 's/^Summary: //')
	if [[ -n "$summary" ]]; then
		clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
		new_branch="${jira_ticket}-${clean_summary}"
		if [[ "$current_branch" == "$new_branch" ]]; then
			print -P "%F{green}Branch name already matches desired format. No changes made.%f"
			exit 0
		fi
		git branch -m "$new_branch"
		print -P "%F{green}Branch renamed to: $new_branch%f"
	else
		print -P "%F{red}Could not fetch summary. No changes made.%f"
	fi
	exit 0
fi

print -P "%F{cyan}Enter new branch name or JIRA ticket (e.g., ABC-123): %f"
read -r input
if [[ -z "$input" ]]; then
	print -P "%F{red}No input provided. Aborting.%f"
	exit 1
fi
if [[ "$input" =~ $jira_pattern ]]; then
	require_tool jira
	print -P "%F{yellow}JIRA ticket detected. Fetching summary via jira CLI...%f"
	summary=$(jira issue view "$input" --plain | grep '^Summary:' | sed 's/^Summary: //')
	if [[ -n "$summary" ]]; then
		clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
		new_branch="${input}-${clean_summary}"
	else
		new_branch="$input"
	fi
else
	new_branch="$input"
fi
git branch -m "$new_branch"
print -P "%F{green}Branch renamed to: $new_branch%f"
