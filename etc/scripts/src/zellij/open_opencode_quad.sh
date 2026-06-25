#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Open a new tab with a 2x2 grid of 4 panes, each running opencode in the target
# directory (defaults to $PWD). Used by the "Alt a" project picker
# (open_select_opencode.sh), which passes the chosen project directory so all
# four opencode instances start in the same project.
main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool opencode || exit 1

	local target_dir="${1:-$PWD}"
	if [[ ! -d "$target_dir" ]]; then
		log_error "Directory does not exist: $target_dir"
		exit 1
	fi

	# Open a plain new tab rooted at the target dir, named after the project
	# folder (new-tab prints the created tab's id on stdout), then build the 2x2
	# opencode grid by splitting panes inside it. Every pane gets an explicit
	# --cwd so it launches opencode in the chosen project regardless of layout
	# inheritance.
	local tab_id
	tab_id="$(zellij action new-tab --cwd "$target_dir")"
	sleep 0.2
	if [[ "$tab_id" =~ ^[0-9]+$ ]]; then
		zellij action rename-tab --tab-id "$tab_id" "$(basename "$target_dir")"
	else
		zellij action rename-tab "$(basename "$target_dir")"
	fi

	# Top-left: run opencode in the new tab's initial shell pane.
	zellij action write-chars "opencode"
	zellij action write 13
	sleep 0.1

	# Top-right
	zellij action new-pane --direction right --cwd "$target_dir" -- opencode
	sleep 0.1

	# Bottom-right (split the top-right pane downward)
	zellij action new-pane --direction down --cwd "$target_dir" -- opencode
	sleep 0.1

	# Bottom-left (move back to the top-left pane and split it downward)
	zellij action move-focus left
	zellij action new-pane --direction down --cwd "$target_dir" -- opencode
	sleep 0.1

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
