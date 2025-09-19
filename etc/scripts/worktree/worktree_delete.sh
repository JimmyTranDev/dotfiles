git worktree list | while read -r line; do
done

#!/bin/zsh
# worktree_delete.sh - Delete a git worktree interactively or by path
# Usage: zsh worktree_delete.sh [worktree_path]

set -e
autoload -U colors && colors

function require_tool() {
  if ! command -v "$1" &>/dev/null; then
    print -P "%F{red}Error: Required tool '$1' not found.%f"
    exit 1
  fi
}
require_tool git
require_tool fzf

WORKTREES_DIR="$HOME/Worktrees"

if [[ $# -eq 1 ]]; then
  WORKTREE_PATH="$1"
else
  WORKTREE_PATH=$(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | sort | fzf --prompt="Select a worktree to delete: ")
  if [[ -z "$WORKTREE_PATH" ]]; then
    print -P "%F{red}No worktree selected.%f"
    exit 1
  fi
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
  print -P "%F{red}Error: Directory $WORKTREE_PATH does not exist.%f"
  exit 1
fi

if [[ ! -f "$WORKTREE_PATH/.git" ]]; then
  print -P "%F{red}Error: $WORKTREE_PATH does not look like a git worktree (missing .git file).%f"
  exit 1
fi

GITDIR_LINE=$(head -n1 "$WORKTREE_PATH/.git")
if [[ "$GITDIR_LINE" =~ ^gitdir:\ (.*)$ ]]; then
  WORKTREE_GITDIR="${BASH_REMATCH[1]}"
  MAIN_REPO=$(dirname "$(dirname "$WORKTREE_GITDIR")")
else
  print -P "%F{red}Error: Could not parse .git file in $WORKTREE_PATH%f"
  exit 1
fi

print -P "%F{yellow}Main repo detected at: $MAIN_REPO%f"

if git -C "$MAIN_REPO" worktree list | grep -q " $WORKTREE_PATH "; then
  print -P "%F{yellow}Removing worktree via git...%f"
  git -C "$MAIN_REPO" worktree remove "$WORKTREE_PATH"
else
  print -P "%F{yellow}Worktree not listed in git, pruning stale references...%f"
  git -C "$MAIN_REPO" worktree prune
fi

if [[ -d "$WORKTREE_PATH" ]]; then
  print -P "%F{yellow}Deleting directory $WORKTREE_PATH...%f"
  rm -rf "$WORKTREE_PATH"
else
  print -P "%F{green}Directory $WORKTREE_PATH already deleted.%f"
fi

print -P "%F{green}✅ Worktree deletion complete.%f"
