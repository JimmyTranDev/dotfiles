#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf nvim || exit 1

	# 1. Resolve the target project with NO prompt, keyed to where you already
	#    are -- the pane to the right, then the current pane, then the last
	#    project -- mirroring Alt ] (open_project_last.sh). Alt ' always opens
	#    nvim, so it shouldn't ask which project either; only fall back to the
	#    shared fzf picker when none of those resolve. Cancelling it exits cleanly.
	local target_dir
	target_dir="$(right_pane_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Open nvim in a new stacked pane rooted at the resolved project (mirrors
	#    Alt ] / open_project_last.sh). open_tool_pane runs nvim in a --stacked pane
	#    with --close-on-exit and renames the focused tab after the project
	#    folder; reindex tab names afterward.
	open_tool_pane "$target_dir" "nvim"

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
