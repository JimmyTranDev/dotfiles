#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Reuse the last "Alt [" tool choice (~/.last_pane_tool) with no prompt,
	# falling back to an empty shell when nothing is recorded yet.
	local tool
	tool="$(last_pane_tool)" || tool="empty"
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	# Open in the directory of the pane to the right (no prompt). Fall back to
	# the current pane, then the last project, then the fzf picker, when the
	# right pane's cwd can't be resolved (e.g. outside a tracked dir).
	local target_dir
	target_dir="$(right_pane_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
