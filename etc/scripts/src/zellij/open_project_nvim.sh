#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf nvim || exit 1

	# 1. Pick the project to open nvim in with the shared fzf picker (projects
	#    and worktrees, most-recently-used first). Unlike Alt ]
	#    (open_ai_chat.sh), Alt ' does NOT peek at the pane to the right, so
	#    it never shifts focus right-then-left; it always prompts you to choose
	#    the project instead. Cancelling the picker exits cleanly.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Open nvim in a new stacked pane rooted at the chosen project.
	#    open_tool_pane runs nvim in a --stacked pane that drops into an
	#    interactive shell when nvim exits, and renames the focused tab after
	#    the project folder; reindex tab names afterward.
	open_tool_pane "$target_dir" "nvim"

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
