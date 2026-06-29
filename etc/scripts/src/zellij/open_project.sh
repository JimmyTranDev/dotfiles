#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# 1. Resolve the target dir first (pane to the right, current pane, last
	#    project, then fzf picker) so the tool picker can offer THIS project's
	#    last choice. Any failure exits cleanly.
	local target_dir
	target_dir="$(right_pane_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Pick what to open with this project's last tool floated to the top:
	#    nvim, opencode, storecode, gh-dash, or an empty shell. Cancelling exits.
	local tool
	tool="$(select_pane_tool "$target_dir")" || exit 0
	[[ -z "$tool" ]] && exit 0
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	# Remember the tool for this project so "Alt ]" reopens it the same way.
	save_pane_tool "$tool" "$target_dir"

	# 3. Open the chosen tool in a new stacked pane and reindex tab names.
	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
