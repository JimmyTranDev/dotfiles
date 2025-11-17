#!/bin/bash
# utility.sh - Common reusable functions for dotfiles scripts

# Setup colors for both bash and zsh
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U colors && colors
elif [[ -n "$BASH_VERSION" ]]; then
  # Define color variables for bash
  if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
  fi
fi

require_tool() {
  if ! command -v "$1" &>/dev/null; then
    if [[ -n "$ZSH_VERSION" ]]; then
      print -P "%F{red}Error: Required tool '$1' not found.%f"
    else
      echo -e "${RED}Error: Required tool '$1' not found.${NC}"
    fi
    exit 1
  fi
}

slugify() {
  local input="$1"
  echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

fzf_select_and_cd() {
  local prompt="$1"
  local base_dir="$2"
  local last_file="$3"
  local open_cmd="$4"
  shift 4
  local items=("$@")
  local last_sel=""
  [[ -f "$last_file" ]] && last_sel=$(<"$last_file")
  local sorted_items=()
  if [[ -n "$last_sel" ]]; then
    for i in "${items[@]}"; do
      if [[ "$i" == "$last_sel" ]]; then
        sorted_items=("$i")
      fi
    done
    for i in "${items[@]}"; do
      if [[ "$i" != "$last_sel" ]]; then
        sorted_items+=("$i")
      fi
    done
  else
    sorted_items=("${items[@]}")
  fi
  local selected
  selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="$prompt")
  if [[ -n "$selected" ]]; then
    echo "$selected" > "$last_file"
    cd "$base_dir/$selected"
    [[ -n "$open_cmd" ]] && eval "$open_cmd"
  else
    echo "No selection."
    return 1
  fi
}

find_git_repos() {
  local base_dir="$1"
  local max_depth="${2:-2}"
  
  # Ensure base_dir has a trailing slash for proper path substitution
  base_dir="${base_dir%/}/"
  
  # Find all .git directories and extract the repo names
  find "$base_dir" -maxdepth "$max_depth" -name ".git" -type d 2>/dev/null | while read -r git_dir; do
    # Get the parent directory of .git (which is the repo root)
    repo_path=$(dirname "$git_dir")
    # Get the relative path from base_dir
    relative_path="${repo_path#$base_dir}"
    echo "$relative_path"
  done | sort
}

find_git_worktrees() {
  local base_dir="$1"
  local max_depth="${2:-2}"
  
  # Ensure base_dir has a trailing slash for proper path substitution
  base_dir="${base_dir%/}/"
  
  # Find all .git files (not directories) which indicate worktrees
  find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while read -r git_file; do
    # Verify it's actually a worktree by checking if it contains "gitdir:"
    if grep -q "^gitdir:" "$git_file" 2>/dev/null; then
      # Get the parent directory (which is the worktree root)
      worktree_path=$(dirname "$git_file")
      # Get the relative path from base_dir
      relative_path="${worktree_path#$base_dir}"
      echo "$relative_path"
    fi
  done | sort
}

find_non_git_dirs() {
  local base_dir="$1"
  local max_depth="${2:-1}"
  
  # Ensure base_dir has a trailing slash for proper path substitution
  base_dir="${base_dir%/}/"
  
  # Find all directories at the specified depth that are not git repositories
  find "$base_dir" -maxdepth "$max_depth" -type d 2>/dev/null | while read -r dir; do
    # Skip the base directory itself
    if [[ "$dir" == "${base_dir%/}" ]]; then
      continue
    fi
    
    # Check if it's not a git repository (no .git directory or file)
    if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
      # Get the relative path from base_dir
      relative_path="${dir#$base_dir}"
      # Only include top-level directories (no subdirectories)
      if [[ "$relative_path" != */* ]]; then
        echo "$relative_path"
      fi
    fi
  done | sort
}

find_git_repos_and_worktrees() {
  local base_dir="$1"
  local max_depth="${2:-2}"
  
  # Ensure base_dir has a trailing slash for proper path substitution
  base_dir="${base_dir%/}/"
  
  # Find both regular git repositories (.git directories) and worktrees (.git files)
  {
    # Find git repositories (.git directories)
    find "$base_dir" -maxdepth "$max_depth" -name ".git" -type d 2>/dev/null | while read -r git_dir; do
      repo_path=$(dirname "$git_dir")
      relative_path="${repo_path#$base_dir}"
      echo "$relative_path"
    done
    
    # Find git worktrees (.git files with gitdir: references)
    find "$base_dir" -maxdepth "$max_depth" -name ".git" -type f 2>/dev/null | while read -r git_file; do
      if grep -q "^gitdir:" "$git_file" 2>/dev/null; then
        worktree_path=$(dirname "$git_file")
        relative_path="${worktree_path#$base_dir}"
        echo "$relative_path"
      fi
    done
  } | sort -u
}

find_all_projects() {
  local base_dir="$1"
  local max_depth="${2:-2}"
  
  # Combine git repositories and non-git directories
  {
    find_git_repos "$base_dir" "$max_depth"
    find_non_git_dirs "$base_dir" 1
  } | sort -u
}

fzf_select_git_worktree_and_cd() {
  local prompt="$1"
  local base_dir="$2"
  local last_file="$3"
  local open_cmd="$4"
  local max_depth="${5:-2}"
  
  # Get all git worktrees in the base directory
  local git_worktrees
  git_worktrees=($(find_git_worktrees "$base_dir" "$max_depth"))
  
  if [[ ${#git_worktrees[@]} -eq 0 ]]; then
    echo "No git worktrees found in $base_dir"
    return 1
  fi
  
  local last_sel=""
  [[ -f "$last_file" ]] && last_sel=$(<"$last_file")
  local sorted_worktrees=()
  
  # Prioritize the last selected worktree
  if [[ -n "$last_sel" ]]; then
    for worktree in "${git_worktrees[@]}"; do
      if [[ "$worktree" == "$last_sel" ]]; then
        sorted_worktrees=("$worktree")
      fi
    done
    for worktree in "${git_worktrees[@]}"; do
      if [[ "$worktree" != "$last_sel" ]]; then
        sorted_worktrees+=("$worktree")
      fi
    done
  else
    sorted_worktrees=("${git_worktrees[@]}")
  fi
  
  local selected
  selected=$(printf "%s\n" "${sorted_worktrees[@]}" | fzf --prompt="$prompt")
  if [[ -n "$selected" ]]; then
    echo "$selected" > "$last_file"
    cd "$base_dir/$selected"
    [[ -n "$open_cmd" ]] && eval "$open_cmd"
  else
    echo "No selection."
    return 1
  fi
}

fzf_select_git_repos_and_worktrees_and_cd() {
  local prompt="$1"
  local base_dir="$2"
  local last_file="$3"
  local open_cmd="$4"
  local max_depth="${5:-2}"
  
  # Get all git repositories and worktrees in the base directory
  local git_items
  git_items=($(find_git_repos_and_worktrees "$base_dir" "$max_depth"))
  
  if [[ ${#git_items[@]} -eq 0 ]]; then
    echo "No git repositories or worktrees found in $base_dir"
    return 1
  fi
  
  local last_sel=""
  [[ -f "$last_file" ]] && last_sel=$(<"$last_file")
  local sorted_items=()
  
  # Prioritize the last selected item
  if [[ -n "$last_sel" ]]; then
    for item in "${git_items[@]}"; do
      if [[ "$item" == "$last_sel" ]]; then
        sorted_items=("$item")
      fi
    done
    for item in "${git_items[@]}"; do
      if [[ "$item" != "$last_sel" ]]; then
        sorted_items+=("$item")
      fi
    done
  else
    sorted_items=("${git_items[@]}")
  fi
  
  local selected
  selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="$prompt")
  if [[ -n "$selected" ]]; then
    echo "$selected" > "$last_file"
    cd "$base_dir/$selected"
    [[ -n "$open_cmd" ]] && eval "$open_cmd"
  else
    echo "No selection."
    return 1
  fi
}

fzf_select_git_repo_and_cd() {
  local prompt="$1"
  local base_dir="$2"
  local last_file="$3"
  local open_cmd="$4"
  local max_depth="${5:-2}"
  
  # Get all git repositories in the base directory
  local git_repos
  git_repos=($(find_git_repos "$base_dir" "$max_depth"))
  
  if [[ ${#git_repos[@]} -eq 0 ]]; then
    echo "No git repositories found in $base_dir"
    return 1
  fi
  
  local last_sel=""
  [[ -f "$last_file" ]] && last_sel=$(<"$last_file")
  local sorted_repos=()
  
  # Prioritize the last selected repo
  if [[ -n "$last_sel" ]]; then
    for repo in "${git_repos[@]}"; do
      if [[ "$repo" == "$last_sel" ]]; then
        sorted_repos=("$repo")
      fi
    done
    for repo in "${git_repos[@]}"; do
      if [[ "$repo" != "$last_sel" ]]; then
        sorted_repos+=("$repo")
      fi
    done
  else
    sorted_repos=("${git_repos[@]}")
  fi
  
  local selected
  selected=$(printf "%s\n" "${sorted_repos[@]}" | fzf --prompt="$prompt")
  if [[ -n "$selected" ]]; then
    echo "$selected" > "$last_file"
    cd "$base_dir/$selected"
    [[ -n "$open_cmd" ]] && eval "$open_cmd"
  else
    echo "No selection."
    return 1
  fi
}

fzf_select_all_projects_and_cd() {
  local prompt="$1"
  local base_dir="$2"
  local last_file="$3"
  local open_cmd="$4"
  local max_depth="${5:-2}"
  
  # Get all projects (git repos and non-git directories) in the base directory
  local all_projects
  all_projects=($(find_all_projects "$base_dir" "$max_depth"))
  
  if [[ ${#all_projects[@]} -eq 0 ]]; then
    echo "No projects found in $base_dir"
    return 1
  fi
  
  local last_sel=""
  [[ -f "$last_file" ]] && last_sel=$(<"$last_file")
  local sorted_projects=()
  
  # Prioritize the last selected project
  if [[ -n "$last_sel" ]]; then
    for project in "${all_projects[@]}"; do
      if [[ "$project" == "$last_sel" ]]; then
        sorted_projects=("$project")
      fi
    done
    for project in "${all_projects[@]}"; do
      if [[ "$project" != "$last_sel" ]]; then
        sorted_projects+=("$project")
      fi
    done
  else
    sorted_projects=("${all_projects[@]}")
  fi
  
  local selected
  selected=$(printf "%s\n" "${sorted_projects[@]}" | fzf --prompt="$prompt")
  if [[ -n "$selected" ]]; then
    echo "$selected" > "$last_file"
    cd "$base_dir/$selected"
    [[ -n "$open_cmd" ]] && eval "$open_cmd"
  else
    echo "No selection."
    return 1
  fi
}
