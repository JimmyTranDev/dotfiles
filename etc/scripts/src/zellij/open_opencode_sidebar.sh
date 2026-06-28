#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."
LAYOUT="$HOME/.config/zellij/layouts/opencode-sidebar.kdl"

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Render the sidebar layout with $1 as the sidebar command, printing the path to
# a freshly-created temp layout file (in its own temp dir). The base structure
# stays defined once in opencode-sidebar.kdl; only the sidebar's command is
# swapped. "empty" yields a plain shell pane (no command, so its close_on_exit is dropped).
render_sidebar_layout() {
	local tool="$1"
	local out_dir out
	out_dir="$(mktemp -d)"
	out="$out_dir/sidebar.kdl"
	if [[ "$tool" == "empty" ]]; then
		sed 's|pane command="opencode" close_on_exit=true|pane|' "$LAYOUT" >"$out"
	else
		sed "s|pane command=\"opencode\"|pane command=\"$tool\"|" "$LAYOUT" >"$out"
	fi
	printf '%s' "$out"
}

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	# nvim is the layout's fixed right-hand editor pane; the sidebar tool is
	# validated after it is chosen below.
	require_tool fzf nvim || exit 1

	# 1. Pick the sidebar tool (nvim, opencode, storecode, ... or empty), using
	#    the same picker as Alt [. Cancelling exits cleanly.
	local tool
	tool="$(select_pane_tool)" || exit 0
	[[ -z "$tool" ]] && exit 0
	[[ "$tool" != "empty" ]] && { require_tool "$tool" || exit 1; }

	# 2. Pick the project/worktree with the shared fzf picker.
	local target_dir
	target_dir="$(select_project_dir)" || exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Mirror the chosen tool into ~/.last_pane_tool so the picker offers it first;
	# the project is already mirrored into ~/.last_project by select_project_dir.
	printf '%s' "$tool" >"$HOME/.last_pane_tool"

	# 3. Open the sidebar layout (the chosen tool stacked on the left + one big
	#    nvim pane on the right) rooted in the chosen project. new-tab prints the
	#    created tab's id on stdout; reindexing below prepends the position
	#    number, e.g. "7.my-project".
	local layout
	layout="$(render_sidebar_layout "$tool")"
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
