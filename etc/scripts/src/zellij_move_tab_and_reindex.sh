#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	local direction="${1:-right}"
	zellij action move-tab "$direction"

	sleep 0.1

	"$SCRIPT_DIR/zellij_update_tab_indexes.sh"
}

main "$@"
