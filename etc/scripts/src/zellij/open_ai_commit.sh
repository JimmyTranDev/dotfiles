#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"

# Alt c: the /commit-running sibling of Alt ] (open_ai_chat.sh). It resolves THIS
# project and its AI agent exactly like Alt ], but instead of opening the agent
# bare it opens it with the /commit command already submitted, so the agent
# commits the already-staged changes. Interactive by design -- the agent TUI
# stays open so you can watch/steer the commit.
main() {
	[[ -z "$ZELLIJ" ]] && exit 0

	require_tool fzf || exit 1

	# Resolve the target dir before opening the tool, so the commit is keyed to
	# THIS project. Identical fallback chain to open_ai_chat.sh: prefer the
	# visible editor pane BY NAME (nvim keeps its pane name synced to the
	# worktree, so it stays correct even when an in-place worktree switch has
	# left the pane's recorded cwd stale), then the pane cwd, the focused pane,
	# the last project, then an fzf picker.
	local target_dir
	target_dir="$(visible_project_dir_by_name)" \
		|| target_dir="$(visible_project_dir)" \
		|| target_dir="$(current_pane_dir)" \
		|| target_dir="$(last_project_dir)" \
		|| target_dir="$(select_project_dir)" \
		|| exit 0
	[[ -z "$target_dir" ]] && exit 0

	# Same repo -> agent routing as Alt ]: personal (jimmytrandev) repos open
	# opencode, everything else opens storecode. The per-project saved tool
	# (~/.pane_tool_by_project, used by Alt p) is deliberately NOT consulted --
	# committing always goes through the repo's AI agent.
	local tool
	tool="$(resolve_repo_agent "$target_dir")"

	require_tool "$tool" || exit 1

	# The two agents take an initial prompt differently: opencode via --prompt,
	# storecode (Claude Code wrapper) as a positional arg. agent_commit_argv
	# prints the right tokens (one per line) for the resolved agent; slurp every
	# line into an array in one read (NUL-delimited so a multi-token agent like
	# opencode isn't truncated to its first line) so each token stays a distinct
	# argv entry. This is the mapfile-free form that works on macOS bash 3.2.
	local -a commit_argv
	IFS=$'\n' read -r -d '' -a commit_argv < <(agent_commit_argv "$tool" && printf '\0')

	# Build a single shell command "<tool> <argv...>; exec zsh -i" so the pane
	# drops into an interactive shell in the project dir when the agent exits
	# instead of vanishing -- the same behaviour open_tool_pane gives Alt ]
	# (which can't carry the extra commit argv). printf %q quotes the tool and
	# every argv token so the /commit arg survives the extra shell hop intact.
	local pane_cmd
	printf -v pane_cmd '%q ' "$tool" "${commit_argv[@]}"
	pane_cmd="${pane_cmd}; exec zsh -i"

	# Open that command in a new stacked pane rooted at the project, rename the
	# focused tab after the project folder, then reindex tab names.
	zellij action new-pane --cwd "$target_dir" --stacked -- \
		zsh -c "$pane_cmd"
	zellij action rename-tab "$(basename "$target_dir")"

	"$SCRIPT_DIR/update_tab_indexes.sh"
}

main "$@"
