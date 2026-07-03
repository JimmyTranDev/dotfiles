#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Alt p: pick a project, then open the 30% opencode / 70% nvim SPLIT LAYOUT (the
# sidebar) in a new tab rooted in that project -- NOT a single stacked pane
# (that's Alt ]). The sidebar tool is ALWAYS opencode and the main pane is ALWAYS
# nvim, so there is no tool prompt: after the project pick the layout opens
# straight away. The layout is defined once in layouts/opencode-sidebar.kdl
# (opencode left, nvim right/focused) and opened as-is -- no per-tool render.
main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	# Both panes' commands must exist: nvim is the main pane, opencode the sidebar.
	require_tool fzf nvim opencode || exit 1

	# 1. Pick the project/worktree with the shared fzf picker.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Open the sidebar layout (opencode stacked on the left + one big nvim
	#    pane on the right) in a new tab rooted in the chosen project. The
	#    installed layout under ~/.config/zellij already runs opencode + nvim, so
	#    it is opened directly. new-tab prints the created tab's id on stdout;
	#    reindexing below prepends the position number, e.g. "7.my-project".
	local layout="$HOME/.config/zellij/layouts/opencode-sidebar.kdl"
	local tab_id
	tab_id="$(zellij action new-tab --cwd "$target_dir" --layout "$layout")"
	if [[ "$tab_id" =~ ^[0-9]+$ ]]; then
		zellij action rename-tab --tab-id "$tab_id" "$(basename "$target_dir")"
	else
		zellij action rename-tab "$(basename "$target_dir")"
	fi

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
