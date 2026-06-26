#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# 1. Pick what to open: nvim, opencode, storecode, or an empty shell.
	#    Cancelling the picker exits cleanly.
	local tool
	tool="$(select_pane_tool)" || exit 0
	[[ -z "$tool" ]] && exit 0
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	# 2. Pick the project/worktree with the shared fzf picker (same as Alt p).
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Remember the tool so "Alt ]" can reopen with the same settings. The project
	# is already mirrored into ~/.last_project by select_project_dir.
	printf '%s' "$tool" >"$HOME/.last_pane_tool"

	# 3. Open the chosen tool in a new stacked pane and reindex tab names.
	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
