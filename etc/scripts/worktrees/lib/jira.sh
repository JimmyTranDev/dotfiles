#!/bin/zsh
# ===================================================================
# jira.sh - Simplified JIRA Integration
# ===================================================================

# Get JIRA summary - returns summary string or fails
get_jira_summary() {
	local jira_key="$1"

	if [[ -z "$jira_key" ]]; then
		return 1
	fi

	if ! command -v jira >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		return 1
	fi

	local jira_raw
	jira_raw=$(jira issue view "$jira_key" --raw 2>/dev/null) || return 1

	local summary
	summary=$(echo "$jira_raw" | jq -r '.fields.summary' 2>/dev/null) || return 1

	if [[ -z "$summary" || "$summary" == "null" ]]; then
		return 1
	fi

	echo "$summary"
}
