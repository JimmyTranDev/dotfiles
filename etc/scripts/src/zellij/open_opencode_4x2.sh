#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT="$HOME/.config/zellij/layouts/opencode-4x2.kdl"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	# Open a new tab using the 4x2 grid layout
	# (4 columns x 2 rows = 8 plain shell panes), then reindex tabs.
	zellij action new-tab --cwd "$PWD" --layout "$LAYOUT"
	sleep 0.2

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
