#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	if ! command -v opencode &>/dev/null; then
		echo "opencode is not installed" >&2
		exit 1
	fi

	# Open a plain new tab first, then build the 2x2 opencode grid by
	# splitting panes inside that new tab.
	zellij action new-tab --cwd "$PWD"
	sleep 0.2

	# Top-left: run opencode in the initial shell pane of the new tab.
	zellij action write-chars "opencode"
	zellij action write 13
	sleep 0.1

	# Top-right
	zellij action new-pane --direction right --cwd "$PWD" -- opencode
	sleep 0.1

	# Bottom-right (split the top-right pane downward)
	zellij action new-pane --direction down --cwd "$PWD" -- opencode
	sleep 0.1

	# Bottom-left (move back to the top-left pane and split it downward)
	zellij action move-focus left
	zellij action new-pane --direction down --cwd "$PWD" -- opencode
	sleep 0.1

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
