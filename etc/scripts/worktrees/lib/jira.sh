#!/bin/zsh
# ===================================================================
# jira.sh - Simplified JIRA Integration using acli
# ===================================================================

# Get JIRA summary - returns summary string or fails
get_jira_summary() {
	local jira_key="$1"

	if [[ -z "$jira_key" ]]; then
		return 1
	fi

	if ! command -v acli >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
		return 1
	fi

	local jira_raw
	jira_raw=$(acli jira workitem view "$jira_key" --json --fields summary 2>/dev/null) || return 1

	local summary
	summary=$(echo "$jira_raw" | jq -r '.[0].fields.summary' 2>/dev/null) || return 1

	if [[ -z "$summary" || "$summary" == "null" ]]; then
		return 1
	fi

	echo "$summary"
}
