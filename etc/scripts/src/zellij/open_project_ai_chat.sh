#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Alt .: like Alt ] (open THIS repo's AI agent as a stacked pane) but ALWAYS
# prompts the fzf project picker first, so it can target ANY project instead of
# auto-resolving the current one. Everything else matches open_ai_chat.sh:
# the agent is resolved from the CHOSEN repo (personal repos -> opencode,
# everything else -> storecode), opened as a stacked pane in the current tab.
main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Always pick the project explicitly -- no visible/pane/last auto-resolve.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Resolve the agent from the chosen repo, same as Alt ]: the per-project
	# saved tool (used by Alt p) is deliberately NOT consulted.
	local tool
	tool="$(resolve_repo_agent "$target_dir")"

	require_tool "$tool" || exit 1

	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
