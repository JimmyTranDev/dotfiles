#!/bin/zsh
# ===================================================================
# rename.sh - Rename Branch Command
# ===================================================================

# Rename current branch subcommand
cmd_rename() {
	if ! check_tool git; then
		return 1
	fi

	local repo_root
	repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
		print_color red "Error: Not in a git repository"
		return 1
	}

	local current_branch
	current_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
		print_color red "Error: Could not determine current branch"
		return 1
	}

	print_color cyan "Current branch: $current_branch"

	local JIRA_PATTERN_UNANCHORED='[A-Z]+-[0-9]+'

	# Check if branch already contains JIRA ticket
	if [[ "$current_branch" =~ $JIRA_PATTERN_UNANCHORED ]]; then
		if ! check_tool acli; then
			print_color red "acli not available. Cannot fetch ticket details."
			return 1
		fi

		local jira_ticket
		jira_ticket="$MATCH"
		print_color yellow "Branch already contains JIRA ticket: $jira_ticket"
		print_color yellow "Fetching summary via acli..."

		local summary
		summary=$(get_jira_summary "$jira_ticket" 2>/dev/null)
		if [[ $? -eq 0 && -n "$summary" ]]; then
			local clean_summary
			clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
			local new_branch="${jira_ticket}-${clean_summary}"

			if [[ "$current_branch" == "$new_branch" ]]; then
				print_color green "Branch name already matches desired format. No changes made."
				return 0
			fi

			git -C "$repo_root" branch -m "$new_branch" || {
				print_color red "Failed to rename branch"
				return 1
			}

			print_color green "Branch renamed to: $new_branch"
			return 0
		else
			print_color red "Could not fetch summary. No changes made."
			return 1
		fi
	fi

	# Get user input for new branch name
	print_color cyan "Enter new branch name or JIRA ticket (e.g., ABC-123): "
	read -r input

	if [[ -z "$input" ]]; then
		print_color red "No input provided. Aborting."
		return 1
	fi

	local new_branch="$input"

	# Check if input is a JIRA ticket
	if [[ "$input" =~ $JIRA_PATTERN_UNANCHORED ]]; then
		if ! check_tool acli; then
			print_color yellow "acli not available. Using input as branch name without JIRA integration."
			new_branch="$input"
		else
			print_color yellow "JIRA ticket detected. Fetching summary via acli..."

			local summary
			summary=$(get_jira_summary "$input" 2>/dev/null)
			if [[ $? -eq 0 && -n "$summary" ]]; then
				local clean_summary
				clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
				new_branch="${input}-${clean_summary}"
			else
				print_color yellow "Could not fetch JIRA summary. Using ticket number as branch name."
				new_branch="$input"
			fi
		fi
	fi

	git -C "$repo_root" branch -m "$new_branch" || {
		print_color red "Failed to rename branch"
		return 1
	}

	print_color green "Branch renamed to: $new_branch"
}
