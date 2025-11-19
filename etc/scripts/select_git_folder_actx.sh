#!/bin/bash

# Script to select a git folder from ~/Programming and create a symlink with -actx suffix
# Also includes functionality to select worktree folders

select_git_folder_actx() {
  local programming_dir="$HOME/Programming"
  
  # Check if Programming directory exists
  if [[ ! -d "$programming_dir" ]]; then
    echo "Error: $programming_dir directory not found"
    return 1
  fi
  
  # Check if fzf is available
  if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is required but not installed"
    echo "Install with: brew install fzf"
    return 1
  fi
  
  # Find all git repositories using a much more efficient approach
  local git_repos=()
  
  echo "Searching for git repositories..."
  
  # Method 1: Check direct subdirectories first (most common case)
  for dir in "$programming_dir"/*; do
    if [[ -d "$dir/.git" ]]; then
      local relative_path="${dir#$programming_dir/}"
      git_repos+=("$relative_path")
    fi
  done
  
  # Method 2: If we found some repos, we're probably good
  if [[ ${#git_repos[@]} -gt 0 ]]; then
    echo "Found ${#git_repos[@]} repositories in direct subdirectories"
  else
    echo "No direct git repositories found, searching one level deeper..."
    # Only search 2 levels deep to avoid infinite loops
    for dir in "$programming_dir"/*/*; do
      if [[ -d "$dir/.git" ]]; then
        local relative_path="${dir#$programming_dir/}"
        git_repos+=("$relative_path")
      fi
      # Limit to prevent too many results
      if [[ ${#git_repos[@]} -gt 100 ]]; then
        echo "Found too many repositories (>100), stopping search..."
        break
      fi
    done
  fi
  
  # Check if any git repos were found
  if [[ ${#git_repos[@]} -eq 0 ]]; then
    echo "No git repositories found in $programming_dir"
    return 1
  fi
  
  # Use fzf to select a repository, with fallback for non-interactive mode
  local selected_repo
  
  # Check if we're in an interactive terminal and fzf can work properly
  if [[ -t 0 && -t 1 ]] && command -v fzf &> /dev/null && [[ -n "$TERM" ]] && [[ "$TERM" != "dumb" ]]; then
    # Try fzf - if it works, great; if not, we'll fall back
    selected_repo=$(printf '%s\n' "${git_repos[@]}" | fzf --prompt="Select git repo: " --height=40% --border 2>/dev/null) || selected_repo=""
  fi
  
    # Fallback: show numbered list and read selection
    echo "Available repositories:"
    for i in "${!git_repos[@]}"; do
      echo "$((i+1)). ${git_repos[i]}"
    done
    
    echo -n "Enter repository number (1-${#git_repos[@]}): "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#git_repos[@]}" ]]; then
      selected_repo="${git_repos[$((selection-1))]}"
    else
      echo "Invalid selection"
      return 1
    fi
  fi
  
  # Check if selection was made
  if [[ -z "$selected_repo" ]]; then
    echo "No repository selected"
    return 1
  fi
  
  local source_path="$programming_dir/$selected_repo"
  local target_name="${selected_repo##*/}-actx"
  local target_path="$(pwd)/$target_name"
  
  # Check if source exists
  if [[ ! -d "$source_path" ]]; then
    echo "Error: Source directory $source_path not found"
    return 1
  fi
  
  # Check if target already exists
  if [[ -e "$target_path" ]]; then
    echo "Warning: $target_name already exists in current directory"
    read -p "Do you want to remove it and create a new symlink? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      rm -rf "$target_path"
    else
      echo "Operation cancelled"
      return 1
    fi
  fi
  
  # Create the symlink
  if ln -s "$source_path" "$target_path"; then
    echo "Successfully created symlink: $target_name -> $selected_repo"
    echo "Source: $source_path"
    echo "Target: $target_path"
  else
    echo "Error: Failed to create symlink"
    return 1
  fi
}

# Run the function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  select_git_folder_actx "$@"
fi