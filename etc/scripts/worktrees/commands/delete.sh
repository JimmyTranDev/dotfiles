#!/bin/zsh
# ===================================================================
# delete.sh - Delete Worktree Command
# ===================================================================

# Delete worktree subcommand
cmd_delete() {
  if ! check_tool git; then
    return 1
  fi
  
  if ! check_tool fzf; then
    return 1
  fi
  
  local worktree_path="$1"
  
  # Select worktree if not provided
  if [[ -z "$worktree_path" ]]; then
    if [[ ! -d "$WORKTREES_DIR" ]]; then
      print_color red "Worktrees directory $WORKTREES_DIR does not exist"
      return 1
    fi
    
    local available_worktrees
    available_worktrees=( $(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | sort) )
    
    if [[ ${#available_worktrees[@]} -eq 0 ]]; then
      print_color red "No worktrees found in $WORKTREES_DIR"
      return 1
    fi
    
    worktree_path=$(select_fzf "Select a worktree to delete: " "${available_worktrees[@]}") || {
      print_color red "No worktree selected."
      return 1
    }
  fi
  
  # Validate worktree
  if [[ ! -d "$worktree_path" ]]; then
    print_color red "Error: Directory $worktree_path does not exist."
    return 1
  fi
  
  if [[ ! -f "$worktree_path/.git" ]]; then
    print_color red "Error: $worktree_path does not look like a git worktree (missing .git file)."
    return 1
  fi
  
  # Detect main repo
  local gitdir_line
  gitdir_line=$(head -n1 "$worktree_path/.git")
  
  local worktree_gitdir
  if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
    worktree_gitdir="${match[1]}"
  else
    print_color red "Error: Could not parse .git file in $worktree_path"
    return 1
  fi
  
  # Get the actual repository root (not the .git directory)
  local main_repo
  main_repo=$(dirname "$(dirname "$worktree_gitdir")")
  print_color yellow "Main repo detected at: $main_repo"
  
  # Change to main repo directory before git operations
  cd "$main_repo" || {
    print_color red "Error: Could not change to main repo directory"
    return 1
  }
  
  # Detect branch name using git worktree list
  local branch_name
  local worktree_info
  worktree_info=$(git worktree list --porcelain | grep -A2 "^worktree $worktree_path$" | grep "^branch " | head -1)
  
  if [[ -n "$worktree_info" ]]; then
    branch_name=$(echo "$worktree_info" | sed 's/^branch refs\/heads\///')
  fi
  
  if [[ -z "$branch_name" ]]; then
    print_color yellow "Could not detect branch name from git worktree list"
  else
    print_color yellow "Detected branch name: '$branch_name'"
  fi
  
  # Remove worktree and branches
  if [[ -n "$branch_name" ]]; then
    print_color yellow "Deleting worktree and branch: $branch_name"
    
    # Remove worktree first
    if [[ -d "$worktree_path" ]]; then
      if git worktree remove "$worktree_path" 2>/dev/null; then
        print_color green "Successfully removed worktree: $worktree_path"
      else
        print_color yellow "Failed to remove worktree cleanly, forcing removal..."
        git worktree remove --force "$worktree_path" 2>/dev/null || true
      fi
    else
      print_color yellow "Worktree directory doesn't exist, pruning from git..."
      git worktree prune 2>/dev/null || true
    fi
    
    # Remove local branch
    print_color yellow "Removing local branch: $branch_name"
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      git branch -d "$branch_name" 2>/dev/null || git branch -D "$branch_name" 2>/dev/null || true
      print_color green "Successfully removed local branch: $branch_name"
    else
      print_color yellow "Local branch $branch_name does not exist"
    fi
    
    # Check if remote branch exists and delete it
    if git ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
      print_color yellow "Deleting remote branch: origin/$branch_name"
      if git push origin --delete "$branch_name" 2>/dev/null; then
        print_color green "Successfully deleted remote branch: origin/$branch_name"
      else
        print_color red "Failed to delete remote branch: origin/$branch_name"
      fi
    else
      print_color yellow "Remote branch origin/$branch_name does not exist or already deleted"
    fi
  else
    print_color yellow "Could not detect branch name, attempting cleanup anyway..."
    git worktree prune 2>/dev/null || true
    
    if [[ -d "$worktree_path" ]]; then
      git worktree remove "$worktree_path" 2>/dev/null || git worktree remove --force "$worktree_path" 2>/dev/null || true
    fi
  fi
  
  # Always attempt to remove directory if it still exists
  if [[ -d "$worktree_path" ]]; then
    print_color yellow "Force removing directory $worktree_path..."
    rm -rf "$worktree_path" || true
  fi
  
  print_color green "✅ Worktree deletion complete."
}
