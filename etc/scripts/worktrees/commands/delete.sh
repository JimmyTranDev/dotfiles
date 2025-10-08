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
  
  # Detect branch name using multiple methods
  local branch_name
  
  print_color yellow "Attempting to detect branch name..."
  
  # Method 1: Try to get branch from the worktree directory itself
  if [[ -d "$worktree_path" ]]; then
    print_color yellow "Method 1: Checking branch from worktree directory"
    local old_pwd="$PWD"
    cd "$worktree_path" 2>/dev/null && {
      branch_name=$(git branch --show-current 2>/dev/null)
      if [[ -n "$branch_name" ]]; then
        print_color green "Found branch from worktree directory: $branch_name"
      fi
      cd "$old_pwd"
    }
  fi
  
  # Method 2: Parse git worktree list output
  if [[ -z "$branch_name" ]]; then
    print_color yellow "Method 2: Parsing git worktree list"
    local worktree_list_output
    worktree_list_output=$(git worktree list --porcelain 2>/dev/null)
    
    # Find the worktree entry and get the next branch line
    local found_worktree=false
    while IFS= read -r line; do
      if [[ "$line" == "worktree $worktree_path" ]]; then
        found_worktree=true
      elif [[ "$found_worktree" == true && "$line" =~ ^branch ]]; then
        branch_name=$(echo "$line" | sed 's/^branch refs\/heads\///')
        print_color green "Found branch from worktree list: $branch_name"
        break
      elif [[ "$found_worktree" == true && "$line" =~ ^worktree ]]; then
        # Hit another worktree entry, stop looking
        break
      fi
    done <<< "$worktree_list_output"
  fi
  
  # Method 3: Try basename matching in worktree list
  if [[ -z "$branch_name" ]]; then
    print_color yellow "Method 3: Trying basename matching"
    local worktree_basename=$(basename "$worktree_path")
    local worktree_list_output
    worktree_list_output=$(git worktree list --porcelain 2>/dev/null)
    
    local found_worktree=false
    while IFS= read -r line; do
      if [[ "$line" =~ worktree.*/$worktree_basename$ ]]; then
        found_worktree=true
      elif [[ "$found_worktree" == true && "$line" =~ ^branch ]]; then
        branch_name=$(echo "$line" | sed 's/^branch refs\/heads\///')
        print_color green "Found branch from basename matching: $branch_name"
        break
      elif [[ "$found_worktree" == true && "$line" =~ ^worktree ]]; then
        break
      fi
    done <<< "$worktree_list_output"
  fi
  
  # Method 4: Extract from directory name (last resort)
  if [[ -z "$branch_name" ]]; then
    print_color yellow "Method 4: Extracting from directory name"
    local dir_name=$(basename "$worktree_path")
    # Common patterns: BW-1234_description, feature/BW-1234, etc.
    if [[ "$dir_name" =~ ^(BW-[0-9]+) ]]; then
      branch_name="$match[1]"
      print_color yellow "Extracted branch from directory name: $branch_name"
    elif [[ "$dir_name" =~ _(.+)$ ]]; then
      # Remove prefix before underscore
      branch_name=$(echo "$dir_name" | sed 's/^[^_]*_//')
      print_color yellow "Extracted branch from directory name: $branch_name"
    fi
  fi
  
  if [[ -z "$branch_name" ]]; then
    print_color yellow "Could not detect branch name from git worktree list"
  else
    print_color yellow "Detected branch name: '$branch_name'"
  fi
  
  # Remove worktree first (regardless of branch detection)
  print_color yellow "Removing worktree: $worktree_path"
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
  
  # Remove branches if detected
  if [[ -n "$branch_name" ]]; then
    print_color yellow "Deleting branch: $branch_name"
    
    # Remove local branch
    print_color yellow "Removing local branch: $branch_name"
    if git show-ref --verify --quiet "refs/heads/$branch_name"; then
      if git branch -d "$branch_name" 2>/dev/null; then
        print_color green "Successfully removed local branch: $branch_name"
      elif git branch -D "$branch_name" 2>/dev/null; then
        print_color green "Force removed local branch: $branch_name"
      else
        print_color red "Failed to remove local branch: $branch_name"
      fi
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
    print_color red "Could not detect branch name - branch cleanup skipped"
    print_color yellow "You may need to manually delete the branch associated with this worktree"
  fi
  
  # Always attempt to remove directory if it still exists
  if [[ -d "$worktree_path" ]]; then
    print_color yellow "Force removing directory $worktree_path..."
    rm -rf "$worktree_path" || true
  fi
  
  print_color green "✅ Worktree deletion complete."
}
