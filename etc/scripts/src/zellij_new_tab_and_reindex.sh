#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	zellij action new-tab

	sleep 0.1

	"$SCRIPT_DIR/zellij_update_tab_indexes.sh"
}

main "$@"
