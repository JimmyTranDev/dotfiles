#!/bin/zsh
# remove_merged_worktrees.sh - Remove git worktrees whose branches have been merged into main
# Usage: zsh remove_merged_worktrees.sh

set -e
autoload -U colors && colors

require_tool() {
  if ! command -v "$1" &>/dev/null; then
    print -P "%F{red}Error: Required tool '$1' not found.%f"
    exit 1
  fi
}
require_tool git

main_branch="main"
repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

print -P "%F{yellow}Scanning for merged worktrees...%f"
git worktree list | while read -r line; do
  worktree_path=$(echo "$line" | awk '{print $1}')
  branch_ref=$(echo "$line" | grep -oE ' \[.*\]' | sed 's/\[//;s/\]//')
  branch_name=""
  if [[ "$branch_ref" == refs/heads/* ]]; then
    branch_name=${branch_ref#refs/heads/}
  fi
  if [[ -z "$branch_name" || "$branch_name" == "$main_branch" ]]; then
    continue
  fi
  if git branch --merged "$main_branch" | grep -q "^  $branch_name$"; then
    print -P "%F{yellow}Removing merged worktree: $worktree_path (branch: $branch_name)%f"
    git worktree remove "$worktree_path"
    git branch -d "$branch_name"
  fi
done
print -P "%F{green}Done removing merged worktrees.%f"
