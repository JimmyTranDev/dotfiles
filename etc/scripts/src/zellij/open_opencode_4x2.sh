#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT="$HOME/.config/zellij/layouts/opencode-4x2.kdl"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	if ! command -v opencode &>/dev/null; then
		echo "opencode is not installed" >&2
		exit 1
	fi

	# Open a new tab using the 4x2 opencode grid layout
	# (4 columns x 2 rows = 8 opencode panes), then reindex tabs.
	zellij action new-tab --cwd "$PWD" --layout "$LAYOUT"
	sleep 0.2

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
