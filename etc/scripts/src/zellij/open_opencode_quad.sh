#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAYOUT_FILE="$HOME/.config/zellij/layouts/opencode-quad.kdl"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	if ! command -v opencode &>/dev/null; then
		echo "opencode is not installed" >&2
		exit 1
	fi

	if [[ ! -f "$LAYOUT_FILE" ]]; then
		echo "Layout not found: $LAYOUT_FILE" >&2
		exit 1
	fi

	zellij action new-tab --layout "$LAYOUT_FILE" --cwd "$PWD"

	sleep 0.1

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
