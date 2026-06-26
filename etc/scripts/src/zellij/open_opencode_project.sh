#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf opencode || exit 1

	# Pick a project/worktree with the same fzf picker as "Alt p"
	# (select_project_dir lives in utils/utility.sh); cancelling exits cleanly.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Open opencode in a new stacked pane rooted in the chosen project. The pane
	# closes itself when opencode exits (--close-on-exit).
	zellij action new-pane --cwd "$target_dir" --stacked --close-on-exit -- opencode

	# Name the focused tab after the project folder; the stacked pane above lands
	# in the current (focused) tab. Reindex afterward so it shows "N.<folder>",
	# matching the Alt p sidebar launcher. No tab id or sleep needed: rename-tab
	# targets the focused tab, which already exists.
	zellij action rename-tab "$(basename "$target_dir")"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
