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

	# 2. Open nvim in a new tab rooted at the chosen project. new-tab prints the
	#    created tab's id on stdout; reindexing below prepends the position
	#    number, e.g. "7.my-project". --close-on-exit drops the tab when nvim
	#    quits.
	local tab_id
	tab_id="$(zellij action new-tab --cwd "$target_dir" --close-on-exit -- nvim)"
	sleep 0.2
	if [[ "$tab_id" =~ ^[0-9]+$ ]]; then
		zellij action rename-tab --tab-id "$tab_id" "$(basename "$target_dir")"
	else
		zellij action rename-tab "$(basename "$target_dir")"
	fi

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
