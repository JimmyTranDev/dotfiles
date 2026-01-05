#!/bin/zsh
# ===================================================================
# worktrees.sh - Unified Git Worktree Management Script
# ===================================================================
# 
# A comprehensive tool for managing git worktrees with JIRA integration.
# Supports creating, deleting, cleaning, renaming, moving, and checking out worktrees across
# multiple repositories with automatic dependency installation.
#
# Usage: zsh worktrees.sh <create|delete|clean|rename|checkout|move> [args]
#
# Dependencies:
#   - git (required)
#   - fzf (required) 
#   - jira CLI (optional, for JIRA integration)
#   - jq (optional, for JIRA JSON parsing)
#
# Author: Jimmy Tran
# ===================================================================

set -e

# Source utility functions
source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

# ===================================================================
# CONFIGURATION
# ===================================================================

WORKTREES_DIR="$HOME/Worktrees"
PROGRAMMING_DIR="$HOME/Programming"

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================


# Print colored message
print_color() {
  local color="$1"; shift
  print -P "%F{$color}$*%f"
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

# Remove worktree and branch
remove_worktree_and_branch() {
  local repo="$1" worktree_path="$2" branch_name="$3"
  git -C "$repo" worktree remove "$worktree_path" || return 1
  git -C "$repo" branch -d "$branch_name" || return 1
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
      # Use parameter expansion instead of command substitution to avoid output
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

# Get JIRA summary with error handling
get_jira_summary() {
  local jira_key="$1"
  
  if [[ -z "$jira_key" ]]; then
    print_color red "Error: JIRA key is required"
    return 1
  fi
  
  if ! command -v jira >/dev/null 2>&1; then
    print_color red "JIRA CLI not found. Please install it first."
    return 1
  fi
  
  if ! command -v jq >/dev/null 2>&1; then
    print_color red "jq not found. Please install it first."
    return 1
  fi
  
  local jira_raw
  if ! jira_raw=$(jira issue view "$jira_key" --raw 2>/dev/null); then
    print_color red "Failed to fetch JIRA ticket: $jira_key"
    return 1
  fi
  
  local summary
  if ! summary=$(echo "$jira_raw" | jq -r '.fields.summary' 2>/dev/null); then
    print_color red "Failed to parse JIRA response for: $jira_key"
    return 1
  fi
  
  if [[ -z "$summary" || "$summary" == "null" ]]; then
    print_color red "Could not extract summary from JIRA ticket: $jira_key"
    return 1
  fi
  
  echo "$summary"
}

# Format branch name
format_branch_name() {
  local prefix="$1" jira_key="$2" summary="$3"
  
  if [[ -z "$prefix" || -z "$jira_key" || -z "$summary" ]]; then
    print_color red "Error: All parameters required for branch name formatting"
    return 1
  fi
  
  local jira_key_low slug
  jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
  slug=$(slugify "$summary")
  echo "${prefix}/${jira_key_low}_${slug}"
}

# Format commit title
format_commit_title() {
  local prefix="$1" emoji="$2" jira_key="$3" summary="$4"
  
  if [[ -z "$prefix" || -z "$emoji" || -z "$jira_key" || -z "$summary" ]]; then
    print_color red "Error: All parameters required for commit title formatting"
    return 1
  fi
  
  local jira_key_up summary_commit
  jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
  summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
  echo "${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
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

# ===================================================================
# COMMAND FUNCTIONS
# ===================================================================

usage() {
  print -P "%F{yellow}Usage:%f zsh worktrees.sh <create|delete|clean|rename|checkout|move|update> [args]"
  print -P "%F{yellow}Subcommands:%f"
  print -P "  create    - Create a new worktree (interactive, JIRA supported)"
  print -P "  delete    - Delete a worktree (interactive or by path)"
  print -P "  clean     - Remove worktrees whose branches are merged into main"
  print -P "  rename    - Rename current branch (JIRA supported)"
  print -P "  checkout  - Checkout a remote branch locally (interactive)"
  print -P "  move      - Move a worktree to a new location (interactive)"
  print -P "  update    - Pull and rebase all worktrees in ~/Worktrees"
  exit 1
}

# Create worktree subcommand
cmd_create() {
  require_tool git
  require_tool fzf
  
  mkdir -p "$WORKTREES_DIR"
  
  local repo_dir
  repo_dir=$(setup_project) || return 1
  
  # Fetch latest develop branch
  git -C "$repo_dir" fetch origin develop 2>/dev/null || 
    print_color yellow "Warning: Could not fetch 'develop' branch."
  
  # Select change type and emoji
  local types=(ci build docs feat perf refactor style test fix revert)
  local emojis=("👷" "📦" "📚" "✨" "🚀" "🔨" "💎" "🧪" "🐛" "⏪")
  
  local type_sel
  type_sel=$(select_fzf "Select change type: " "${types[@]}") || {
    print_color red "No change type selected."
    return 1
  }
  
  local prefix emoji
  # Find the index of the selected type and get corresponding emoji
  for i in {1..${#types[@]}}; do
    if [[ "$type_sel" == "${types[$i]}" ]]; then
      prefix="$type_sel"
      emoji="${emojis[$i]}"
      break
    fi
  done
  
  if [[ -z "$prefix" || -z "$emoji" ]]; then
    print_color red "Error: Failed to set prefix or emoji for type '$type_sel'"
    return 1
  fi
  
  print_color yellow "Selected: $prefix ($emoji)"
  
  # Handle JIRA ticket or manual entry
  local jira_key summary branch_name commit_title folder_name description
  
  print_color cyan "Do you have a Jira ticket? (y/n): "
  read -r has_jira
  
  if [[ "$has_jira" =~ ^[Yy]$ ]]; then
    # JIRA flow
    print_color cyan "Enter Jira ticket number (e.g. SB-1234): "
    read -r jira_key
    
    if [[ -z "$jira_key" ]]; then
      print_color red "No Jira key entered."
      return 1
    fi
    
    print_color yellow "Fetching Jira ticket details for $jira_key..."
    
    if ! summary=$(get_jira_summary "$jira_key"); then
      return 1
    fi
    
    print_color green "Found: $summary"
    
    if ! branch_name=$(format_branch_name "$prefix" "$jira_key" "$summary"); then
      return 1
    fi
    
    if ! commit_title=$(format_commit_title "$prefix" "$emoji" "$jira_key" "$summary"); then
      return 1
    fi
    
    local jira_key_up slug
    jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
    slug=$(slugify "$summary")
    folder_name="${jira_key_up}_${slug}"
    
    # Set description without JIRA link since ORG_JIRA_TICKET_LINK is no longer available
    print_color yellow "Note: JIRA ticket link functionality removed."
    description=""
    fi
  else
    # Manual flow
    print_color cyan "Enter branch slug (lowercase, hyphens, e.g., my-feature): "
    read -r slug
    
    if [[ -z "$slug" ]]; then
      print_color red "Slug cannot be empty."
      return 1
    fi
    
    local slugified_name
    slugified_name=$(slugify "$slug")
    branch_name="${prefix}/${slugified_name}"
    
    local summary_commit
    summary_commit=$(echo "$slug" | tr '-' ' ')
    commit_title="${prefix}: ${emoji} ${summary_commit}"
    folder_name="$slugified_name"
  fi
  
  local worktree_path="$WORKTREES_DIR/${folder_name}"
  
  # Create worktree
  if ! git -C "$repo_dir" worktree add -b "$branch_name" "$worktree_path"; then
    print_color red "Failed to create worktree. It may already exist."
    return 1
  fi
  
  print_color green "Worktree created at: $worktree_path"
  print_color green "Branch: $branch_name"
  
  # Install dependencies
  install_dependencies "$worktree_path"
  
  # Create initial commit
  git -C "$worktree_path" commit --allow-empty -m "$commit_title" ${description:+-m "$description"}
  
  print_color green "Worktree created successfully!"
}

# Checkout remote branch subcommand
cmd_checkout() {
  require_tool git
  require_tool fzf
  
  local repo_dir
  repo_dir=$(setup_project) || return 1
  
  # Fetch latest remote refs
  git -C "$repo_dir" fetch origin || {
    print_color red "Failed to fetch from origin"
    return 1
  }
  
  # Get all remote branches
  local all_remote_branches
  all_remote_branches=( $(git -C "$repo_dir" branch -r | grep '^  origin/' | sed 's/^  origin\///' | grep -vE '^HEAD$' | sort) )
  
  if [[ ${#all_remote_branches[@]} -eq 0 ]]; then
    print_color red "No remote branches found"
    return 1
  fi
  
  local branch_sel
  branch_sel=$(select_fzf "Select remote branch to checkout: " "${all_remote_branches[@]}") || {
    print_color red "No branch selected."
    return 1
  }
  
  local local_branch="$branch_sel"
  
  mkdir -p "$WORKTREES_DIR"
  
  local folder_name
  folder_name=$(get_folder_name_from_branch "$local_branch") || return 1
  
  local worktree_path="$WORKTREES_DIR/${folder_name}"
  
  # Check if worktree already exists
  if [[ -d "$worktree_path" ]]; then
    print_color yellow "Worktree already exists at: $worktree_path"
    
    # Check if it's a valid git worktree
    if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
      print_color green "Switching to existing worktree: $worktree_path"
      cd "$worktree_path" || {
        print_color red "Error: Could not change to worktree directory"
        return 1
      }
      print_color green "Successfully switched to worktree!"
      return 0
    else
      # Directory exists but not a valid worktree, ask user what to do
      print_color yellow "Directory exists but is not a valid git worktree."
      print -P "%F{cyan}Options:%f"
      print -P "  1) Remove directory and create new worktree"
      print -P "  2) Cancel operation"
      
      local choice
      read -r "choice?Enter your choice (1-2): "
      
      case "$choice" in
        1)
          rm -rf "$worktree_path" || {
            print_color red "Failed to remove existing directory"
            return 1
          }
          print_color green "Removed existing directory"
          ;;
        *)
          print_color yellow "Operation cancelled"
          return 0
          ;;
      esac
    fi
  fi
  
  # Create the worktree
  if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$local_branch"; then
    print_color yellow "Local branch '$local_branch' already exists. Creating worktree from existing branch."
    
    # First try to create worktree normally
    if ! git -C "$repo_dir" worktree add "$worktree_path" "$local_branch" 2>/dev/null; then
      # If it fails, check if it's a registered but missing worktree
      if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
        print_color yellow "Worktree is registered but missing. Cleaning up and recreating..."
        git -C "$repo_dir" worktree remove "$worktree_path" 2>/dev/null || true
      fi
      
      # Try again with force flag if needed
      if ! git -C "$repo_dir" worktree add "$worktree_path" "$local_branch"; then
        print_color red "Failed to create worktree from existing branch."
        return 1
      fi
    fi
  else
    print_color green "Creating new branch '$local_branch' with worktree."
    
    # First try to create worktree normally
    if ! git -C "$repo_dir" worktree add "$worktree_path" -b "$local_branch" "origin/$local_branch" 2>/dev/null; then
      # If it fails, check if it's a registered but missing worktree
      if git -C "$repo_dir" worktree list | grep -q "$worktree_path"; then
        print_color yellow "Worktree path is registered but missing. Cleaning up and recreating..."
        git -C "$repo_dir" worktree remove "$worktree_path" 2>/dev/null || true
      fi
      
      # Try again
      if ! git -C "$repo_dir" worktree add "$worktree_path" -b "$local_branch" "origin/$local_branch"; then
        print_color red "Failed to create worktree with new branch."
        return 1
      fi
    fi
  fi
  
  print_color green "Worktree created at: $worktree_path"
  
  # Install dependencies
  install_dependencies "$worktree_path"
  
  print_color green "Checkout completed successfully!"
}

# Delete worktree subcommand
cmd_delete() {
  require_tool git
  require_tool fzf
  
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

# Clean merged/deleted branches subcommand
cmd_clean() {
  require_tool git
  require_tool fzf
  
  # Discover all repositories that have worktrees
  local repos_with_worktrees=()
  
  if [[ -d "$WORKTREES_DIR" ]]; then
    print_color yellow "Scanning for repositories with worktrees in $WORKTREES_DIR..."
    
    # Find all worktree directories and extract their parent repositories
    while IFS= read -r -d '' worktree_dir; do
      if [[ -f "$worktree_dir/.git" ]]; then
        local gitdir_line
        gitdir_line=$(head -n1 "$worktree_dir/.git" 2>/dev/null)
        if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
          local worktree_gitdir="${match[1]}"
          local repo_root
          repo_root=$(dirname "$(dirname "$worktree_gitdir")")
          if [[ -d "$repo_root" && ! " ${repos_with_worktrees[@]} " =~ " $repo_root " ]]; then
            repos_with_worktrees+=("$repo_root")
          fi
        fi
      fi
    done < <(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  fi
  
  # If we're in a git repository, add it to the list
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local current_repo
    current_repo=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -n "$current_repo" && ! " ${repos_with_worktrees[@]} " =~ " $current_repo " ]]; then
      repos_with_worktrees+=("$current_repo")
    fi
  fi
  
  if [[ ${#repos_with_worktrees[@]} -eq 0 ]]; then
    print_color red "No repositories with worktrees found."
    return 1
  fi
  
  print_color yellow "Found ${#repos_with_worktrees[@]} repositories with worktrees:"
  for repo in "${repos_with_worktrees[@]}"; do
    print_color yellow "  $(basename "$repo") ($repo)"
  done
  
  # Clean all repositories with worktrees
  for repo_root in "${repos_with_worktrees[@]}"; do
    print_color cyan "===================="
    print_color cyan "Cleaning repository: $(basename "$repo_root")"
    print_color cyan "Path: $repo_root"
    print_color cyan "===================="
    
    local main_branch
    main_branch=$(find_main_branch "$repo_root") || {
      print_color red "Error: Could not find main branch for $(basename "$repo_root"). Skipping."
      continue
    }
    
    print_color yellow "Using main branch: $main_branch"
    print_color yellow "Pulling latest $main_branch..."
    
    if ! git -C "$repo_root" checkout "$main_branch" 2>/dev/null; then
      print_color red "Error: Failed to checkout $main_branch in $(basename "$repo_root"). Skipping."
      continue
    fi
    
    git -C "$repo_root" pull origin "$main_branch" || {
      print_color yellow "Warning: Failed to pull latest $main_branch"
    }
    
    # Fetch latest to get current remote state
    print_color yellow "Fetching latest remote refs..."
    git -C "$repo_root" fetch --prune origin || {
      print_color yellow "Warning: Failed to fetch from origin"
    }
    
    print_color yellow "Finding branches to clean up..."
    
    # Get all local branches except the main branch
    local all_local_branches
    all_local_branches=$(git -C "$repo_root" branch --format='%(refname:short)' 2>/dev/null | grep -v "^$main_branch\$" || true)
    
    if [[ -z "$all_local_branches" ]]; then
      print_color green "No local branches found to evaluate in $(basename "$repo_root")."
      continue
    fi
    
    local branches_to_delete=()
    
    # Process each branch
    while IFS= read -r branch_name; do
      [[ -z "$branch_name" ]] && continue
      [[ "$branch_name" == "$main_branch" ]] && continue
      
      local should_delete=false
      local reason=""
      
      # Method 1: Check if branch is merged
      local merged_check
      merged_check=$(git -C "$repo_root" branch --merged "$main_branch" --format='%(refname:short)' 2>/dev/null | grep "^${branch_name}\$" || true)
      if [[ -n "$merged_check" ]]; then
        should_delete=true
        reason="merged into $main_branch"
      else
        # Method 2: Check if remote branch no longer exists
        if ! git -C "$repo_root" ls-remote --exit-code --heads origin "$branch_name" >/dev/null 2>&1; then
          should_delete=true
          reason="remote branch deleted"
        fi
      fi
      
      if [[ "$should_delete" == "true" ]]; then
        branches_to_delete+=("$branch_name:$reason")
      fi
    done <<< "$all_local_branches"
    
    if [[ ${#branches_to_delete[@]} -eq 0 ]]; then
      print_color green "No branches found to clean up in $(basename "$repo_root")."
      continue
    fi
    
    print_color yellow "Found ${#branches_to_delete[@]} branches to clean up in $(basename "$repo_root"):"
    for branch_info in "${branches_to_delete[@]}"; do
      local branch_name="${branch_info%:*}"
      local reason="${branch_info#*:}"
      print_color yellow "  $branch_name ($reason)"
    done
    
    # Clean up branches with worktrees
    for branch_info in "${branches_to_delete[@]}"; do
      local branch_name="${branch_info%:*}"
      local reason="${branch_info#*:}"
      
      # Find worktree path for this branch
      local worktree_path
      worktree_path=$(git -C "$repo_root" worktree list --porcelain | awk -v branch="refs/heads/$branch_name" '
        $1 == "worktree" { current_path = $2 }
        $1 == "branch" && $2 == branch { print current_path; exit }
      ')
      
      if [[ -n "$worktree_path" && -d "$worktree_path" ]]; then
        print_color yellow "Removing worktree: $worktree_path (branch: $branch_name - $reason)"
        
        # Remove worktree first
        if git -C "$repo_root" worktree remove "$worktree_path" 2>/dev/null; then
          print_color green "Successfully removed worktree: $worktree_path"
        else
          print_color yellow "Failed to remove worktree cleanly, forcing removal..."
          git -C "$repo_root" worktree remove --force "$worktree_path" 2>/dev/null || true
        fi
        
        # Remove directory if it still exists
        if [[ -d "$worktree_path" ]]; then
          print_color yellow "Force removing directory $worktree_path..."
          rm -rf "$worktree_path" 2>/dev/null || true
        fi
        
        # Remove the branch
        print_color yellow "Removing branch: $branch_name"
        git -C "$repo_root" branch -d "$branch_name" 2>/dev/null || git -C "$repo_root" branch -D "$branch_name" 2>/dev/null || true
      else
        print_color yellow "Removing branch: $branch_name ($reason)"
        git -C "$repo_root" branch -d "$branch_name" 2>/dev/null || git -C "$repo_root" branch -D "$branch_name" 2>/dev/null || true
      fi
    done
    
    print_color green "Done cleaning $(basename "$repo_root")."
  done
  
  print_color green "✅ Finished cleaning all repositories with worktrees."
}

# Rename current branch subcommand
cmd_rename() {
  require_tool git
  
  local repo_root
  repo_root=$(git rev-parse --show-toplevel 2>/dev/null) || {
    print_color red "Error: Not in a git repository"
    return 1
  }
  
  local current_branch
  current_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
    print_color red "Error: Could not determine current branch"
    return 1
  }
  
  print_color cyan "Current branch: $current_branch"
  
  local jira_pattern='^[A-Z]+-[0-9]+'
  local jira_ticket
  
  # Check if branch already contains JIRA ticket
  if [[ "$current_branch" =~ $jira_pattern ]]; then
    require_tool jira
    jira_ticket=$(echo "$current_branch" | grep -oE "$jira_pattern")
    print_color yellow "Branch already contains JIRA ticket: $jira_ticket"
    print_color yellow "Fetching summary via JIRA CLI..."
    
    local summary
    if summary=$(jira issue view "$jira_ticket" --plain 2>/dev/null | grep '^Summary:' | sed 's/^Summary: //'); then
      if [[ -n "$summary" ]]; then
        local clean_summary
        clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
        local new_branch="${jira_ticket}-${clean_summary}"
        
        if [[ "$current_branch" == "$new_branch" ]]; then
          print_color green "Branch name already matches desired format. No changes made."
          return 0
        fi
        
        git -C "$repo_root" branch -m "$new_branch" || {
          print_color red "Failed to rename branch"
          return 1
        }
        
        print_color green "Branch renamed to: $new_branch"
        return 0
      fi
    fi
    
    print_color red "Could not fetch summary. No changes made."
    return 1
  fi
  
  # Get user input for new branch name
  print_color cyan "Enter new branch name or JIRA ticket (e.g., ABC-123): "
  read -r input
  
  if [[ -z "$input" ]]; then
    print_color red "No input provided. Aborting."
    return 1
  fi
  
  local new_branch="$input"
  
  # Check if input is a JIRA ticket
  if [[ "$input" =~ $jira_pattern ]]; then
    require_tool jira
    print_color yellow "JIRA ticket detected. Fetching summary via JIRA CLI..."
    
    local summary
    if summary=$(jira issue view "$input" --plain 2>/dev/null | grep '^Summary:' | sed 's/^Summary: //'); then
      if [[ -n "$summary" ]]; then
        local clean_summary
        clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
        new_branch="${input}-${clean_summary}"
      fi
    fi
  fi
  
  git -C "$repo_root" branch -m "$new_branch" || {
    print_color red "Failed to rename branch"
    return 1
  }
  
  print_color green "Branch renamed to: $new_branch"
}

# Move worktree subcommand
cmd_move() {
  require_tool git
  require_tool fzf
  
  local source_path="$1"
  local dest_path="$2"
  
  # Select source worktree if not provided
  if [[ -z "$source_path" ]]; then
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
    
    source_path=$(select_fzf "Select a worktree to move: " "${available_worktrees[@]}") || {
      print_color red "No worktree selected."
      return 1
    }
  fi
  
  # Validate source worktree
  if [[ ! -d "$source_path" ]]; then
    print_color red "Error: Directory $source_path does not exist."
    return 1
  fi
  
  if [[ ! -f "$source_path/.git" ]]; then
    print_color red "Error: $source_path does not look like a git worktree (missing .git file)."
    return 1
  fi
  
  # Get worktree name from path
  local worktree_name
  worktree_name=$(basename "$source_path")
  
  # Get destination path if not provided
  if [[ -z "$dest_path" ]]; then
    print_color cyan "Enter new location for worktree '$worktree_name':"
    print_color yellow "Current location: $source_path"
    print_color yellow "Enter full path or just new parent directory:"
    read dest_path
    
    if [[ -z "$dest_path" ]]; then
      print_color red "No destination path provided."
      return 1
    fi
    
    # If dest_path is just a directory, append the worktree name
    if [[ -d "$dest_path" ]]; then
      dest_path="$dest_path/$worktree_name"
    fi
  fi
  
  # Validate destination
  if [[ -e "$dest_path" ]]; then
    print_color red "Error: Destination $dest_path already exists."
    return 1
  fi
  
  # Create destination directory if parent doesn't exist
  local dest_parent
  dest_parent=$(dirname "$dest_path")
  if [[ ! -d "$dest_parent" ]]; then
    print_color yellow "Creating parent directory: $dest_parent"
    mkdir -p "$dest_parent" || {
      print_color red "Error: Could not create parent directory $dest_parent"
      return 1
    }
  fi
  
  # Detect main repo
  local gitdir_line
  gitdir_line=$(head -n1 "$source_path/.git")
  
  local worktree_gitdir
  if [[ "$gitdir_line" =~ ^gitdir:\ (.*)$ ]]; then
    worktree_gitdir="${match[1]}"
  else
    print_color red "Error: Could not parse .git file in $source_path"
    return 1
  fi
  
  # Get the actual repository root (not the .git directory)
  local main_repo
  main_repo=$(dirname "$(dirname "$worktree_gitdir")")
  
  print_color yellow "Moving worktree from $source_path to $dest_path..."
  
  # Use git worktree move command
  git -C "$main_repo" worktree move "$source_path" "$dest_path" || {
    print_color red "Error: Failed to move worktree. Check that Git version supports 'git worktree move' (Git 2.17+)"
    return 1
  }
  
  print_color green "Successfully moved worktree to: $dest_path"
  print_color cyan "You can now access the worktree at the new location."
}

# Update all worktrees subcommand
cmd_update() {
  print_color yellow "Updating all worktrees in $WORKTREES_DIR..."
  
  if [[ ! -d "$WORKTREES_DIR" ]]; then
    print_color red "Error: Worktrees directory $WORKTREES_DIR does not exist"
    return 1
  fi
  
  local updated_count=0
  local failed_count=0
  local skipped_count=0
  
  # Find all directories that contain .git files (worktrees)
  while IFS= read -r -d '' worktree_path; do
    local worktree_name="${worktree_path##*/}"
    
    print_color cyan "\n--- Processing worktree: $worktree_name ---"
    
    # Check if it's a valid git worktree
    if [[ ! -f "$worktree_path/.git" ]]; then
      print_color yellow "Skipping $worktree_name: Not a git worktree"
      ((skipped_count++))
      continue
    fi
    
    # Get current branch name
    local current_branch
    current_branch=$(git -C "$worktree_path" rev-parse --abbrev-ref HEAD 2>/dev/null) || {
      print_color red "Error: Failed to get current branch for $worktree_name"
      ((failed_count++))
      continue
    }
    
    # Skip if on detached HEAD
    if [[ "$current_branch" == "HEAD" ]]; then
      print_color yellow "Skipping $worktree_name: In detached HEAD state"
      ((skipped_count++))
      continue
    fi
    
    print_color blue "Current branch: $current_branch"
    
    # Check if there are any uncommitted changes
    if ! git -C "$worktree_path" diff-index --quiet HEAD -- 2>/dev/null; then
      print_color yellow "Warning: $worktree_name has uncommitted changes, skipping..."
      ((skipped_count++))
      continue
    fi
    
    # Check if current branch has a remote tracking branch
    local remote_branch
    remote_branch=$(git -C "$worktree_path" rev-parse --abbrev-ref @{u} 2>/dev/null) || {
      print_color yellow "Skipping $worktree_name: No remote tracking branch for $current_branch"
      ((skipped_count++))
      continue
    }
    
    print_color blue "Remote branch: $remote_branch"
    
    # Fetch latest changes
    print_color blue "Fetching latest changes..."
    if ! git -C "$worktree_path" fetch origin 2>/dev/null; then
      print_color red "Error: Failed to fetch for $worktree_name"
      ((failed_count++))
      continue
    fi
    
    # Check if there are any changes to pull
    local local_commit remote_commit
    local_commit=$(git -C "$worktree_path" rev-parse HEAD)
    remote_commit=$(git -C "$worktree_path" rev-parse @{u})
    
    if [[ "$local_commit" == "$remote_commit" ]]; then
      print_color green "Already up to date: $worktree_name"
      ((updated_count++))
      continue
    fi
    
    # Pull with rebase
    print_color blue "Pulling with rebase..."
    if git -C "$worktree_path" pull --rebase origin "$current_branch" 2>/dev/null; then
      print_color green "Successfully updated: $worktree_name"
      ((updated_count++))
    else
      print_color red "Error: Failed to pull and rebase $worktree_name"
      ((failed_count++))
      
      # Check if there's a rebase in progress and abort it
      if [[ -d "$worktree_path/.git/rebase-merge" ]] || [[ -d "$worktree_path/.git/rebase-apply" ]]; then
        print_color yellow "Aborting rebase for $worktree_name..."
        git -C "$worktree_path" rebase --abort 2>/dev/null || true
      fi
    fi
    
  done < <(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d -print0)
  
  # Print summary
  print_color yellow "\n=== Update Summary ==="
  print_color green "Updated: $updated_count"
  print_color yellow "Skipped: $skipped_count" 
  print_color red "Failed: $failed_count"
  
  if [[ $failed_count -gt 0 ]]; then
    print_color red "\nSome worktrees failed to update. Please check them manually."
    return 1
  else
    print_color green "\nAll worktrees processed successfully!"
    return 0
  fi
}

if [[ $# -lt 1 ]]; then
  usage
fi

# ===================================================================
# MAIN SCRIPT LOGIC
# ===================================================================

subcommand="$1"
shift

case "$subcommand" in
  create)
    cmd_create || exit 1
    ;;
  checkout)
    cmd_checkout || exit 1
    ;;
  delete)
    cmd_delete "$@" || exit 1
    ;;
  clean)
    cmd_clean || exit 1
    ;;
  rename)
    cmd_rename || exit 1
    ;;
  move)
    cmd_move "$@" || exit 1
    ;;
  update)
    cmd_update || exit 1
    ;;
  *)
    usage
    ;;
esac
