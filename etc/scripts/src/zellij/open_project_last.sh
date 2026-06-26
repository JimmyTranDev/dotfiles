#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Reuse the last "Alt [" settings with no prompt: the last tool choice
	# (~/.last_pane_tool) and the last project (~/.last_project). Fall back to an
	# empty shell / the fzf picker when nothing is recorded yet.
	local tool
	tool="$(last_pane_tool)" || tool="empty"
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	local target_dir
	target_dir="$(last_project_dir)" || target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
