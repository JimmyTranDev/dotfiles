#!/bin/zsh
# ===================================================================
# jira.sh - Simplified JIRA Integration using acli
# ===================================================================

# Get JIRA summary - returns summary string or fails
# Set WORKTREE_DEBUG=1 to enable debug output
get_jira_summary() {
	local jira_key="$1"

	if [[ -z "$jira_key" ]]; then
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Error: No JIRA key provided" >&2
		return 1
	fi

	if ! command -v acli >/dev/null 2>&1; then
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Error: acli command not found" >&2
		return 1
	fi

	if ! command -v jq >/dev/null 2>&1; then
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Error: jq command not found" >&2
		return 1
	fi

	local jira_raw
	local acli_exit_code
	jira_raw=$(acli jira workitem view "$jira_key" --json --fields summary 2>&1)
	acli_exit_code=$?

	if [[ $acli_exit_code -ne 0 ]]; then
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Error: acli command failed with exit code $acli_exit_code" >&2
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Output: $jira_raw" >&2
		return 1
	fi

	local summary
	summary=$(echo "$jira_raw" | jq -r '.fields.summary' 2>&1)
	local jq_exit_code=$?

	if [[ $jq_exit_code -ne 0 ]]; then
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Error: jq parsing failed with exit code $jq_exit_code" >&2
		[[ -n "$WORKTREE_DEBUG" ]] && echo "jq output: $summary" >&2
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Raw JSON: $jira_raw" >&2
		return 1
	fi

	if [[ -z "$summary" || "$summary" == "null" ]]; then
		[[ -n "$WORKTREE_DEBUG" ]] && echo "Error: Summary is empty or null" >&2
		return 1
	fi

	echo "$summary"
}
