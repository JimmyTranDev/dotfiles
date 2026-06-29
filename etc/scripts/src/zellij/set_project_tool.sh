#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# 1. Resolve the target dir (pane to the right, current pane, last project,
	#    then fzf picker) so we set the tool for THIS project. Any failure exits
	#    cleanly.
	local target_dir
	target_dir="$(right_pane_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Pick the tool for this project with its last choice floated to the top:
	#    nvim, opencode, storecode, gh-dash, or an empty shell. Cancelling exits.
	local tool
	tool="$(select_pane_tool "$target_dir")" || exit 0
	[[ -z "$tool" ]] && exit 0

	# 3. Save it as this project's tool so "Alt ]" opens it. Nothing is opened
	#    here -- this only updates the saved tool (no pane, no tab reindex).
	save_pane_tool "$tool" "$target_dir"
}

main "$@"
