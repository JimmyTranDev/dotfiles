#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Alt p: pick a project and a tool, then open the 30% chosen-tool / 70% nvim
# SPLIT LAYOUT (the sidebar) in a new tab rooted in that project -- NOT a single
# stacked pane (that's Alt ]). The base layout lives in
# layouts/opencode-sidebar.kdl; render_sidebar_layout (utils/utility.sh, unit-
# tested in tests/test_sidebar_layout.zsh) stamps the chosen tool into a
# throwaway copy before zellij loads it.
main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	# nvim is the layout's fixed right-hand editor pane; the sidebar tool is
	# validated after it is chosen below.
	require_tool fzf nvim || exit 1

	# 1. Pick the project/worktree with the shared fzf picker.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# 2. Pick the sidebar tool (nvim, opencode, storecode, gh-dash, ... or empty),
	#    using the shared picker with this project's last tool floated first.
	#    Cancelling exits; a non-empty tool is validated once chosen.
	local tool
	tool="$(select_pane_tool "$target_dir")" || exit 0
	[[ -z "$tool" ]] && exit 0
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	# 3. Remember the tool for this project so the picker floats it first next
	#    time; the project is already mirrored into ~/.last_project by
	#    select_project_dir.
	save_pane_tool "$tool" "$target_dir"

	# 4. Open the sidebar layout (the chosen tool stacked on the left + one big
	#    nvim pane on the right) in a new tab rooted in the chosen project.
	#    new-tab prints the created tab's id on stdout; reindexing below prepends
	#    the position number, e.g. "7.my-project".
	local layout
	layout="$(render_sidebar_layout "$tool")" || { log_error "Failed to render the sidebar layout"; exit 1; }
	local tab_id
	tab_id="$(zellij action new-tab --cwd "$target_dir" --layout "$layout")"
	sleep 0.2
	rm -rf "$(dirname "$layout")"
	if [[ "$tab_id" =~ ^[0-9]+$ ]]; then
		zellij action rename-tab --tab-id "$tab_id" "$(basename "$target_dir")"
	else
		zellij action rename-tab "$(basename "$target_dir")"
	fi

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
