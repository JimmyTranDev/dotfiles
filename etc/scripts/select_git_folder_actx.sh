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
  
  # Find all git repositories (directories with .git folder)
  local git_repos=()
  while IFS= read -r -d '' repo; do
    # Get relative path from Programming directory
    local relative_path="${repo#$programming_dir/}"
    # Remove the .git suffix to get clean repo name
    relative_path="${relative_path%/.git}"
    git_repos+=("$relative_path")
  done < <(find "$programming_dir" -name ".git" -type d -print0 2>/dev/null)
  
  # Check if any git repos were found
  if [[ ${#git_repos[@]} -eq 0 ]]; then
    echo "No git repositories found in $programming_dir"
    return 1
  fi
  
  # Use fzf to select a repository
  local selected_repo
  selected_repo=$(printf '%s\n' "${git_repos[@]}" | fzf --prompt="Select git repo: " --height=40% --border)
  
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