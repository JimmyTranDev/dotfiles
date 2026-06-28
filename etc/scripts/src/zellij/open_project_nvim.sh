#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf nvim || exit 1

	# 1. Pick the project/worktree with the shared fzf picker (same one Alt p
	#    uses). Cancelling the picker exits cleanly.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Open nvim in a new stacked pane rooted at the chosen project (mirrors
	#    Alt [ / open_project.sh). open_tool_pane runs nvim in a --stacked pane
	#    with --close-on-exit and renames the focused tab after the project
	#    folder; reindex tab names afterward.
	open_tool_pane "$target_dir" "nvim"

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
