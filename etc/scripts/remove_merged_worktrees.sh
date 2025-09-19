#!/bin/zsh
# Script to remove git worktrees whose branches have been merged into main

set -e

main_branch="main"
repo_root=$(git rev-parse --show-toplevel)

cd "$repo_root"

git worktree list | while read -r line; do
    worktree_path=$(echo "$line" | awk '{print $1}')
    branch_ref=$(echo "$line" | grep -oE ' \[.*\]' | sed 's/\[//;s/\]//')
    branch_name=""
    if [[ "$branch_ref" == refs/heads/* ]]; then
        branch_name=${branch_ref#refs/heads/}
    fi
    # Skip main branch and empty branch names
    if [[ -z "$branch_name" || "$branch_name" == "$main_branch" ]]; then
        continue
    fi
    # Check if branch is merged into main
    if git branch --merged "$main_branch" | grep -q "^  $branch_name$"; then
        echo "Removing merged worktree: $worktree_path (branch: $branch_name)"
        git worktree remove "$worktree_path"
        git branch -d "$branch_name"
    fi
done

echo "Done removing merged worktrees."
