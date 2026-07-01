#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Resolve the target dir (visible editor pane, current pane, last project,
	# then fzf picker) before the tool, so the reopen is keyed to THIS project.
	local target_dir
	target_dir="$(visible_project_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Alt ] only ever opens an AI agent -- the one matching THIS repo: personal
	# (jimmytrandev) repos open opencode, everything else opens storecode.
	# resolve_repo_agent always returns one of those two, so the per-project
	# saved tool (~/.pane_tool_by_project, used by Alt p) is deliberately NOT
	# consulted here -- otherwise a project whose saved tool is nvim/gh-dash/
	# empty would reopen that instead of its agent.
	local tool
	tool="$(resolve_repo_agent "$target_dir")"

	require_tool "$tool" || exit 1

	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
