#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Resolve the target dir (pane to the right, current pane, last project,
	# then fzf picker) before the tool, so the reopen is keyed to THIS project.
	local target_dir
	target_dir="$(right_pane_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Reuse the tool last saved for this project (~/.pane_tool_by_project) with
	# no prompt, falling back to an empty shell when nothing is recorded yet.
	local tool
	tool="$(last_pane_tool "$target_dir")" || tool="empty"

	# Route the two AI agents to the one matching THIS repo (jimmytrandev repos ->
	# opencode, everything else -> storecode); nvim/gh-dash/empty pass through.
	tool="$(normalize_pane_tool "$tool" "$target_dir")"

	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
