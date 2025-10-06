#!/bin/zsh
# ===================================================================
# core.sh - Core Worktree Utilities
# ===================================================================

# Core Worktree Utilities
# Note: Depends on config.sh being sourced

# Safer version of require_tool that doesn't exit
check_tool() {
  local tool="${1:-}"
  if [[ -z "$tool" ]]; then
    print_color red "Error: No tool specified to check"
    return 1
  fi
  if ! command -v "$tool" &>/dev/null; then
    print_color red "Error: Required tool '$tool' not found."
    return 1
  fi
  return 0
}

# Print colored message
print_color() {
  local color="${1:-white}"; shift
  if [[ $# -gt 0 ]]; then
    print -P "%F{$color}$*%f"
  else
    print -P "%F{$color}%f"
  fi
}

# Select from list using fzf
select_fzf() {
  local prompt="$1"; shift
  [[ $# -gt 0 ]] && printf "%s\n" "$@" | fzf --prompt="$prompt" || fzf --prompt="$prompt"
}

# Get package manager in repo
detect_package_manager() {
  [[ -f pnpm-lock.yaml ]] && echo "pnpm" && return
  [[ -f package-lock.json ]] && echo "npm" && return
  [[ -f yarn.lock ]] && echo "yarn" && return
  echo ""
}

# Get folder name from branch name (removes prefix)
get_folder_name_from_branch() {
  local branch_name="$1"
  
  if [[ -z "$branch_name" ]]; then
    print_color red "Error: Branch name is required"
    return 1
  fi
  
  # Remove prefix (everything before and including the first slash)
  if [[ "$branch_name" =~ ^[^/]+/(.+)$ ]]; then
    echo "${match[1]}"
  else
    echo "$branch_name"
  fi
}

# Setup project and validate
setup_project() {
  local proj
  proj=$(select_project) || return 1
  
  if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
    print_color red "No valid project selected."
    return 1
  fi
  
  echo "$proj" > "$HOME/.last_project"
  echo "$PROGRAMMING_DIR/$proj"
}

# Select project interactively, prioritizing last used
select_project() {
  local last_proj_file="$HOME/.last_project"
  local last_proj=""
  [[ -f "$last_proj_file" ]] && last_proj=$(<"$last_proj_file")
  
  # Get all projects safely  
  local all_projects=()
  if [[ -d "$PROGRAMMING_DIR" ]]; then
    while IFS= read -r -d '' dir; do
      all_projects+=("${dir##*/}")
    done < <(find "$PROGRAMMING_DIR" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z)
  fi
  
  if [[ ${#all_projects[@]} -eq 0 ]]; then
    print_color red "No projects found in $PROGRAMMING_DIR"
    return 1
  fi
  
  local projects_list=()
  if [[ -n "$last_proj" ]]; then
    # Add last project first if it exists
    for p in "${all_projects[@]}"; do 
      [[ "$p" == "$last_proj" ]] && projects_list+=("$p")
    done
    # Add remaining projects
    for p in "${all_projects[@]}"; do 
      [[ "$p" != "$last_proj" ]] && projects_list+=("$p")
    done
  else
    projects_list=("${all_projects[@]}")
  fi
  
  select_fzf "Select project folder: " "${projects_list[@]}"
}

# Install dependencies if package manager detected
install_dependencies() {
  local worktree_path="$1"
  
  if [[ -z "$worktree_path" || ! -d "$worktree_path" ]]; then
    print_color red "Error: Invalid worktree path"
    return 1
  fi
  
  cd "$worktree_path" || {
    print_color red "Error: Could not change to worktree directory"
    return 1
  }
  
  local pm
  pm=$(detect_package_manager)
  
  if [[ -n "$pm" ]]; then
    print_color cyan "Running $pm install..."
    if ! "$pm" install; then
      print_color yellow "Warning: $pm install failed"
      return 1
    fi
  else
    print_color yellow "No supported lockfile found. Skipping dependency installation."
  fi
}

# Find main branch (prefer develop, fallback to main)
find_main_branch() {
  local repo_dir="$1"
  
  if [[ -z "$repo_dir" || ! -d "$repo_dir" ]]; then
    print_color red "Error: Invalid repository directory"
    return 1
  fi
  
  local main_branch=""
  for branch in develop main master; do
    if git -C "$repo_dir" rev-parse --verify "$branch" >/dev/null 2>&1; then
      main_branch="$branch"
      break
    fi
  done
  
  if [[ -z "$main_branch" ]]; then
    print_color red "Error: No main branch (develop/main/master) found"
    return 1
  fi
  
  echo "$main_branch"
}

# Validate branch name
is_valid_branch_name() {
  local branch_name="$1"
  
  # Check if empty
  [[ -z "$branch_name" ]] && return 1
  
  # Check for invalid characters (spaces, etc.)
  [[ "$branch_name" =~ [[:space:]] ]] && return 1
  
  # Check for git-invalid characters
  [[ "$branch_name" =~ [\~\^\:\?\*\[\]] ]] && return 1
  
  return 0
}

# Select a git repository from Programming directory
select_repository() {
  local programming_dir="${PROGRAMMING_DIR:-$HOME/Programming}"
  
  if [[ ! -d "$programming_dir" ]]; then
    print_color red "Error: Programming directory not found: $programming_dir" >&2
    return 1
  fi
  
  print_color cyan "Scanning for git repositories in $programming_dir..." >&2
  
  # Create temporary file to store repository paths
  local temp_repos=$(mktemp)
  find "$programming_dir" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read git_dir; do
    dirname "$git_dir" >> "$temp_repos"
  done
  
  if [[ ! -s "$temp_repos" ]]; then
    print_color red "No git repositories found in $programming_dir" >&2
    rm -f "$temp_repos"
    return 1
  fi
  
  local repo_count=$(wc -l < "$temp_repos")
  print_color yellow "Found $repo_count git repositories:" >&2
  
  # Use fzf to select repository if available
  if check_tool fzf; then
    local selected_repo
    selected_repo=$(cat "$temp_repos" | while read repo; do basename "$repo"; done | fzf --prompt="Select repository: " --height=40% --reverse)
    
    if [[ -z "$selected_repo" ]]; then
      print_color red "No repository selected" >&2
      rm -f "$temp_repos"
      return 1
    fi
    
    # Find the full path for the selected repository
    local full_path
    full_path=$(cat "$temp_repos" | while read repo; do
      if [[ "$(basename "$repo")" == "$selected_repo" ]]; then
        echo "$repo"
        break
      fi
    done)
    
    rm -f "$temp_repos"
    echo "$full_path"
    return 0
  else
    # Fallback to manual selection
    local i=1
    cat "$temp_repos" | while read repo; do
      print_color yellow "  $i. $(basename "$repo")" >&2
      ((i++))
    done
    
    print_color cyan "Enter repository number (1-$repo_count): " >&2
    local choice
    read choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le $repo_count ]]; then
      local selected_repo
      selected_repo=$(sed -n "${choice}p" "$temp_repos")
      rm -f "$temp_repos"
      echo "$selected_repo"
      return 0
    else
      print_color red "Invalid selection" >&2
      return 1
    fi
  fi
}

# Find a repository by name in Programming directory
find_repository_by_name() {
  local repo_name="$1"
  local programming_dir="${PROGRAMMING_DIR:-$HOME/Programming}"
  
  if [[ -z "$repo_name" ]]; then
    print_color red "Error: Repository name is required" >&2
    return 1
  fi
  
  if [[ ! -d "$programming_dir" ]]; then
    print_color red "Error: Programming directory not found: $programming_dir" >&2
    return 1
  fi
  
  # Create temporary file to store repository paths
  local temp_repos=$(mktemp)
  find "$programming_dir" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read git_dir; do
    dirname "$git_dir" >> "$temp_repos"
  done
  
  if [[ ! -s "$temp_repos" ]]; then
    print_color red "No git repositories found in $programming_dir" >&2
    rm -f "$temp_repos"
    return 1
  fi
  
  # Look for exact repository name match
  local found_repo
  found_repo=$(cat "$temp_repos" | while read repo; do
    if [[ "$(basename "$repo")" == "$repo_name" ]]; then
      echo "$repo"
      break
    fi
  done)
  
  rm -f "$temp_repos"
  
  if [[ -n "$found_repo" ]]; then
    echo "$found_repo"
    return 0
  else
    print_color red "Error: Repository '$repo_name' not found in $programming_dir" >&2
    print_color yellow "Available repositories:" >&2
    find "$programming_dir" -maxdepth 2 -name ".git" -type d 2>/dev/null | while read git_dir; do
      print_color yellow "  - $(basename "$(dirname "$git_dir")")" >&2
    done
    return 1
  fi
}

# Get repository - either by name or interactive selection
get_repository() {
  local repo_name="$1"
  
  if [[ -n "$repo_name" ]]; then
    # Try to find repository by name
    find_repository_by_name "$repo_name"
  else
    # Interactive selection
    select_repository
  fi
}
