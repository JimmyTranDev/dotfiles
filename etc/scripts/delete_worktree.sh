#!/bin/bash
# delete_worktree.sh
# Usage: ./delete_worktree.sh <worktree_path>

set -euo pipefail

if [ "$#" -eq 1 ]; then
  WORKTREE_PATH="$1"
else
  # Interactive selection from $HOME/Worktrees
  WORKTREE_PATH=$(find "$HOME/Worktrees" -mindepth 1 -maxdepth 1 -type d | fzf --prompt="Select a worktree to delete: ")
  if [ -z "$WORKTREE_PATH" ]; then
    echo "No worktree selected."
    exit 1
  fi
fi

if [ ! -d "$WORKTREE_PATH" ]; then
  echo "Error: Directory $WORKTREE_PATH does not exist."
  exit 1
fi

# Ensure .git file exists
if [ ! -f "$WORKTREE_PATH/.git" ]; then
  echo "Error: $WORKTREE_PATH does not look like a git worktree (missing .git file)."
  exit 1
fi

# Extract main repo path from the .git file
GITDIR_LINE=$(head -n1 "$WORKTREE_PATH/.git")
if [[ "$GITDIR_LINE" =~ ^gitdir:\ (.*)$ ]]; then
  WORKTREE_GITDIR="${BASH_REMATCH[1]}"
  MAIN_REPO=$(dirname "$(dirname "$WORKTREE_GITDIR")")
else
  echo "Error: Could not parse .git file in $WORKTREE_PATH"
  exit 1
fi

echo "Main repo detected at: $MAIN_REPO"

# Remove the worktree from git (if still registered)
if git -C "$MAIN_REPO" worktree list | grep -q " $WORKTREE_PATH "; then
  echo "Removing worktree via git..."
  git -C "$MAIN_REPO" worktree remove "$WORKTREE_PATH"
else
  echo "Worktree not listed in git, pruning stale references..."
  git -C "$MAIN_REPO" worktree prune
fi

# Remove the directory if it still exists
if [ -d "$WORKTREE_PATH" ]; then
  echo "Deleting directory $WORKTREE_PATH..."
  rm -rf "$WORKTREE_PATH"
else
  echo "Directory $WORKTREE_PATH already deleted."
fi

echo "✅ Worktree deletion complete."
