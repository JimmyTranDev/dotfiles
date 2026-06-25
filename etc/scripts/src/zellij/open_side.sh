#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."
LAYOUT="$HOME/.config/zellij/layouts/side.kdl"

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

	# Open the side layout (8-pane opencode grid) rooted in the chosen project.
	# Name the new tab after the project folder (new-tab prints the created tab's
	# id on stdout); reindexing below then prepends the position number,
	# e.g. "7.my-project".
	local tab_id
	tab_id="$(zellij action new-tab --cwd "$target_dir" --layout "$LAYOUT")"
	sleep 0.2
	if [[ "$tab_id" =~ ^[0-9]+$ ]]; then
		zellij action rename-tab --tab-id "$tab_id" "$(basename "$target_dir")"
	else
		zellij action rename-tab "$(basename "$target_dir")"
	fi

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
