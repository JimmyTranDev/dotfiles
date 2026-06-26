#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf opencode || exit 1

	# Reopen the most-recently-selected project (mirrored into ~/.last_project)
	# with no prompt. When no last project is recorded yet, fall back to the
	# same fzf picker as "Alt p" (select_project_dir); cancelling exits cleanly.
	local target_dir
	target_dir="$(last_project_dir)" || target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Open opencode in a new stacked pane rooted in the chosen project. The pane
	# closes itself when opencode exits (--close-on-exit).
	zellij action new-pane --cwd "$target_dir" --stacked --close-on-exit -- opencode
}

main "$@"
