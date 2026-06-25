#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."
LAYOUT="$HOME/.config/zellij/layouts/mass-tab.kdl"

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf nvim opencode || exit 1

	# Pick a project/worktree with the same fzf picker as "Alt p"
	# (select_project_dir lives in utils/utility.sh); cancelling exits cleanly.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Open the mass-tab layout (left column of 4 opencode panes + one big focused
	# nvim pane) rooted in the chosen project, then reindex tabs.
	zellij action new-tab --cwd "$target_dir" --layout "$LAYOUT"
	sleep 0.2

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
