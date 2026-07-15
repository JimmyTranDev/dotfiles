#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Resolve the target dir before opening the tool, so the reopen is keyed to
	# THIS project. Prefer the visible editor pane BY NAME: nvim keeps its pane
	# name synced to the worktree (rename_pane on DirChanged), so it stays
	# correct even when an in-place worktree switch has left the pane's recorded
	# cwd stale. Fall back to the pane cwd, the focused pane, the last project,
	# then an fzf picker.
	local target_dir
	target_dir="$(visible_project_dir_by_name)" \
		|| target_dir="$(visible_project_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# The agent can be FORCED via $1 (Alt u -> storecode, Alt y -> opencode).
	# With no arg (Alt ]) the agent matches THIS repo: personal (jimmytrandev)
	# repos open opencode, everything else opens storecode. resolve_repo_agent
	# always returns one of those two, so the per-project saved tool
	# (~/.pane_tool_by_project, used by Alt p) is deliberately NOT consulted here
	# -- otherwise a project whose saved tool is nvim/gh-dash/empty would reopen
	# that instead of its agent.
	local tool="$1"
	[[ -n "$tool" ]] || tool="$(resolve_repo_agent "$target_dir")"

	require_tool "$tool" || exit 1

	open_tool_pane "$target_dir" "$tool"
	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
