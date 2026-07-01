#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Alt p: pick a project and a tool, then open that tool the same way Alt ] does
# -- as a single stacked pane in the current tab (open_tool_pane). The only
# difference from Alt ] is the front half: Alt p always prompts for the project
# and the tool, whereas Alt ] reuses the pane-to-the-right / last project and the
# tool already saved for it.
main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# 1. Pick the project/worktree with the shared fzf picker.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Pick the tool (nvim, opencode, storecode, gh-dash, ... or empty), using
	#    the shared picker with this project's last tool floated first.
	#    Cancelling exits; a non-empty tool is validated once chosen.
	local tool
	tool="$(select_pane_tool "$target_dir")" || exit 0
	[[ -z "$tool" ]] && exit 0
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	# 3. Remember the tool for this project so Alt ] reuses it; the
	#    project is already mirrored into ~/.last_project by select_project_dir.
	save_pane_tool "$tool" "$target_dir"

	# 4. Open the chosen tool as a new stacked pane in the current tab -- the
	#    identical open path as Alt ] (open_project_last.sh) -- then reindex tab
	#    names so the position prefix stays correct.
	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
