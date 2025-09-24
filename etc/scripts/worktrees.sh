#!/bin/zsh
# worktrees.sh - Unified worktree management script
# Usage: zsh worktrees.sh <create|delete|clean|rename> [args]

set -e

# Source utility functions
source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

# --- Reusable Functions ---


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
  git -C "$repo" worktree remove "$worktree_path"
  git -C "$repo" branch -d "$branch_name"
}

# Select project interactively, prioritizing last used
select_project() {
  local last_proj_file="$HOME/.last_project"
  local last_proj=""
  [[ -f "$last_proj_file" ]] && last_proj=$(<"$last_proj_file")
  local all_projects=( $(ls -d "$PROGRAMMING_DIR"/*/ | sed "s#$PROGRAMMING_DIR/##;s#/##" | sort) )
  local projects_list=()
  if [[ -n "$last_proj" ]]; then
    for p in "${all_projects[@]}"; do [[ "$p" == "$last_proj" ]] && projects_list+=("$p"); done
    for p in "${all_projects[@]}"; do [[ "$p" != "$last_proj" ]] && projects_list+=("$p"); done
  else
    projects_list=("${all_projects[@]}")
  fi
  select_fzf "Select project folder: " "${projects_list[@]}"
}

# Get package manager in repo
function detect_package_manager() {
  if [[ -f pnpm-lock.yaml ]]; then
    echo "pnpm"
  elif [[ -f package-lock.json ]]; then
    echo "npm"
  elif [[ -f yarn.lock ]]; then
    echo "yarn"
  else
    echo ""
  fi
}

# Get JIRA summary (returns empty if not found)
function get_jira_summary() {
  local jira_key="$1"
  jira issue view "$jira_key" --raw | jq -r '.fields.summary'
}

# Format branch name
function format_branch_name() {
  local prefix="$1" jira_key="$2" summary="$3"
  local jira_key_low slug
  jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
  slug=$(slugify "$summary")
  echo "${prefix}/${jira_key_low}_${slug}"
}

# Format commit title
function format_commit_title() {
  local prefix="$1" emoji="$2" jira_key="$3" summary="$4"
  local jira_key_up summary_commit
  jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
  summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
  echo "${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
}


WORKTREES_DIR="$HOME/Worktrees"
PROGRAMMING_DIR="$HOME/Programming"

function usage() {
  print -P "%F{yellow}Usage:%f zsh worktrees.sh <create|delete|clean|rename|checkout> [args]"
  print -P "%F{yellow}Subcommands:%f"
  print -P "  create    - Create a new worktree (interactive, JIRA supported)"
  print -P "  delete    - Delete a worktree (interactive or by path)"
  print -P "  clean     - Remove worktrees whose branches are merged into main"
  print -P "  rename    - Rename current branch (JIRA supported)"
  print -P "  checkout  - Checkout a remote branch locally (interactive)"
  exit 1
}

if [[ $# -lt 1 ]]; then
  usage
fi

subcommand="$1"
shift

case "$subcommand" in
  checkout)
    require_tool git
    require_tool fzf
    local proj
    proj=$(select_project)
    if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
      print_color red "No valid project selected."; exit 1
    fi
    echo "$proj" > "$HOME/.last_project"
    local repo_dir="$PROGRAMMING_DIR/$proj"
    git -C "$repo_dir" fetch origin
    # Get your git user info
    local user_email user_name
    user_email=$(git -C "$repo_dir" config user.email)
    user_name=$(git -C "$repo_dir" config user.name)
    # Get all remote branches
    local all_remote_branches
  all_remote_branches=( $(git -C "$repo_dir" branch -r | grep '^  origin/' | sed 's/^  origin\///' | grep -vE '^HEAD$' | sort) )
    local branch_sel
    branch_sel=$(select_fzf "Select remote branch to checkout: " "${all_remote_branches[@]}")
    [[ -z "$branch_sel" ]] && print_color red "No branch selected." && exit 1
    local local_branch="$branch_sel"
    if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$local_branch"; then
      print_color yellow "Local branch '$local_branch' already exists."
    else
      print_color green "Branch '$local_branch' will be created with worktree."
    fi
    mkdir -p "$WORKTREES_DIR"
    local worktree_path="$WORKTREES_DIR/$(echo "$local_branch" | tr '/' '_')"
    if git -C "$repo_dir" worktree add "$worktree_path" "$local_branch"; then
      print_color green "Worktree created at: $worktree_path"
      cd "$worktree_path" || print_color yellow "Warning: Could not cd to $worktree_path."
      local pm
      pm=$(detect_package_manager)
      if [[ -n "$pm" ]]; then
        print_color cyan "Running $pm install in $worktree_path..."
        "$pm" install
      else
        print_color yellow "No supported lockfile (pnpm-lock.yaml, package-lock.json, yarn.lock) found. Skipping install."
      fi
    else
      print_color red "Failed to create worktree. It may already exist."
    fi
    ;;
  create)
    require_tool git
    require_tool fzf
    mkdir -p "$WORKTREES_DIR"
    local proj
    proj=$(select_project)
    if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
      print_color red "No valid project selected."; exit 1
    fi
    echo "$proj" > "$HOME/.last_project"
    local repo_dir="$PROGRAMMING_DIR/$proj"
    git -C "$repo_dir" fetch origin develop || print_color yellow "Warning: Could not fetch 'develop' branch."
    local types=(ci build docs feat perf refactor style test fix revert)
    local emojis=("👷" "📦" "📚" "✨" "🚀" "🔨" "💎" "🧪" "🐛" "⏪")
    local type_sel
    type_sel=$(select_fzf "Select change type: " "${types[@]}")
    [[ -z "$type_sel" ]] && print_color red "No change type selected." && exit 1
    local prefix emoji
    for i in {1..${#types[@]}}; do :; done # dummy for brace expansion
    for i in "${(@k)types}"; do
      if [[ "$type_sel" == "${types[$i]}" ]]; then
        prefix="$type_sel"; emoji="${emojis[$i]}"; break
      fi
    done
    local jira_key summary branch_name summary_commit commit_title description
    print_color cyan "Do you have a Jira ticket? (y/n): "
    read -r has_jira
    if [[ "$has_jira" =~ ^[Yy]$ ]]; then
      require_tool jira
      require_tool jq
      print_color cyan "Enter Jira ticket number (e.g. SB-1234): "
      read -r jira_key
      [[ -z "$jira_key" ]] && print_color red "No Jira key entered." && exit 1
      summary=$(jira issue view "$jira_key" --raw | jq -r '.fields.summary')
      [[ -z "$summary" ]] && print_color red "Could not fetch summary for $jira_key." && exit 1
      local jira_key_low slug
      jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
      slug=$(slugify "$summary")
      branch_name="${prefix}/${jira_key_low}_${slug}"
      summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
      local jira_key_up
      jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
      commit_title="${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
    else
      print_color cyan "Enter branch slug (lowercase, hyphens, e.g., my-feature): "
      read -r slug
      [[ -z "$slug" ]] && print_color red "Slug cannot be empty." && exit 1
      branch_name="${prefix}/$(slugify "$slug")"
      summary_commit=$(echo "$slug" | tr '-' ' ')
      commit_title="${prefix}: ${emoji} ${summary_commit}"
    fi
    local worktree_path="$WORKTREES_DIR/$(echo "$branch_name" | tr '/' '_')"
    if git -C "$repo_dir" worktree add -b "$branch_name" "$worktree_path"; then
      cd "$worktree_path" || print_color yellow "Warning: Could not cd to $worktree_path."
      print_color green "Changed directory to $worktree_path"
    else
      print_color red "Failed to create worktree. It may already exist."; exit 1
    fi
    local pm
    pm=$(detect_package_manager)
    if [[ -n "$pm" ]]; then
      print_color cyan "Running $pm install..."
      "$pm" install
    else
      print_color yellow "No supported lockfile (pnpm-lock.yaml, package-lock.json, yarn.lock) found."
    fi
    if [[ -n "$jira_key" ]]; then
      if [[ -z "$ORG_JIRA_TICKET_LINK" ]]; then
        print_color yellow "Warning: ORG_JIRA_TICKET_LINK environment variable is not set."
        description=""
      else
        description="Jira: ${ORG_JIRA_TICKET_LINK}${jira_key}"
      fi
    fi
    git -C "$worktree_path" commit --allow-empty -m "$commit_title" ${description:+-m "$description"}
    print_color green "Worktree created successfully at: $worktree_path"
    print_color green "Branch: $branch_name"
    ;;
  delete)
    require_tool git
    require_tool fzf
    # Select worktree path
    if [[ $# -eq 1 ]]; then
      WORKTREE_PATH="$1"
    else
      WORKTREE_PATH=$(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | sort | select_fzf "Select a worktree to delete: ")
      [[ -z "$WORKTREE_PATH" ]] && print_color red "No worktree selected." && exit 1
    fi
    # Validate worktree
    [[ ! -d "$WORKTREE_PATH" ]] && print_color red "Error: Directory $WORKTREE_PATH does not exist." && exit 1
    [[ ! -f "$WORKTREE_PATH/.git" ]] && print_color red "Error: $WORKTREE_PATH does not look like a git worktree (missing .git file)." && exit 1
    # Detect main repo
    GITDIR_LINE=$(head -n1 "$WORKTREE_PATH/.git")
    if [[ "$GITDIR_LINE" =~ ^gitdir:\ (.*)$ ]]; then
      WORKTREE_GITDIR="${match[1]}"
    else
      print_color red "Error: Could not parse .git file in $WORKTREE_PATH"
      exit 1
    fi
    # Get the actual repository root (not the .git directory)
    MAIN_REPO=$(dirname "$(dirname "$WORKTREE_GITDIR")")
    print_color yellow "Main repo detected at: $MAIN_REPO"
    
    # Change to main repo directory before git operations
    cd "$MAIN_REPO"
    
    # Detect branch name using a more reliable method
    BRANCH_NAME=""
    
    # First try the simple approach - get all worktrees and find matching path
    local worktree_info
    worktree_info=$(git worktree list --porcelain | grep -A2 "^worktree $WORKTREE_PATH$" | grep "^branch " | head -1)
    
    if [[ -n "$worktree_info" ]]; then
      BRANCH_NAME=$(echo "$worktree_info" | sed 's/^branch refs\/heads\///')
    fi
    
    # Fallback: try to detect from directory name if the above fails
    if [[ -z "$BRANCH_NAME" ]]; then
      local dir_name=$(basename "$WORKTREE_PATH")
      # Convert directory name back to branch name (reverse the transformation from create)
      BRANCH_NAME=$(echo "$dir_name" | tr '_' '/')
      print_color yellow "Could not detect branch from git, using directory name: $BRANCH_NAME"
    fi
    
    print_color yellow "Detected branch name: '$BRANCH_NAME'"
    
    if [[ -n "$BRANCH_NAME" ]]; then
      print_color yellow "Deleting worktree and branch: $BRANCH_NAME"
      
      # Check if worktree directory actually exists
      if [[ -d "$WORKTREE_PATH" ]]; then
        # Remove worktree first
        if git worktree remove "$WORKTREE_PATH" 2>/dev/null; then
          print_color green "Successfully removed worktree: $WORKTREE_PATH"
        else
          print_color yellow "Failed to remove worktree cleanly, forcing removal..."
          git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
        fi
      else
        # Directory doesn't exist, but git still tracks it - prune it
        print_color yellow "Worktree directory doesn't exist, pruning from git..."
        git worktree prune 2>/dev/null || true
      fi
      
      # Remove local branch
      print_color yellow "Removing local branch: $BRANCH_NAME"
      if git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
        git branch -d "$BRANCH_NAME" 2>/dev/null || git branch -D "$BRANCH_NAME" 2>/dev/null || true
        print_color green "Successfully removed local branch: $BRANCH_NAME"
      else
        print_color yellow "Local branch $BRANCH_NAME does not exist"
      fi
      
      # Check if remote branch exists and delete it
      if git ls-remote --exit-code --heads origin "$BRANCH_NAME" >/dev/null 2>&1; then
        print_color yellow "Deleting remote branch: origin/$BRANCH_NAME"
        if git push origin --delete "$BRANCH_NAME" 2>/dev/null; then
          print_color green "Successfully deleted remote branch: origin/$BRANCH_NAME"
        else
          print_color red "Failed to delete remote branch: origin/$BRANCH_NAME"
        fi
      else
        print_color yellow "Remote branch origin/$BRANCH_NAME does not exist or already deleted"
      fi
    else
      print_color yellow "Could not detect branch name, attempting cleanup anyway..."
      
      # Try to prune worktrees first
      git worktree prune 2>/dev/null || true
      
      # Try to remove the worktree if it exists
      if [[ -d "$WORKTREE_PATH" ]]; then
        git worktree remove "$WORKTREE_PATH" 2>/dev/null || git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true
      fi
    fi
    
    # Always attempt to remove directory if it still exists
    if [[ -d "$WORKTREE_PATH" ]]; then
      print_color yellow "Force removing directory $WORKTREE_PATH..."
      rm -rf "$WORKTREE_PATH" || true
    fi
    print_color green "✅ Worktree deletion complete."
    ;;
  clean)
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
      exit 1
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
    
      # Find the main branch (prefer develop, fallback to main)
      local main_branch=""
      for branch in develop main; do
        if git -C "$repo_root" rev-parse --verify "$branch" >/dev/null 2>&1; then
          main_branch="$branch"
          break
        fi
      done
      
      if [[ -z "$main_branch" ]]; then
        print_color red "Error: Neither 'develop' nor 'main' branch found in $(basename "$repo_root"). Skipping."
        continue
      fi
      
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
      
      # Get all local branches except the main branch and current branch
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
        
        # Method 1: Check if branch is in merged branches list
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
          # Try to remove worktree first
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
    ;;
  rename)
    require_tool git
    repo_root=$(git rev-parse --show-toplevel)
    current_branch=$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)
    print_color cyan "Current branch: $current_branch"
    jira_pattern='^[A-Z]+-[0-9]+'
    if [[ "$current_branch" =~ $jira_pattern ]]; then
      require_tool jira
      print_color yellow "Branch already contains JIRA ticket: $jira_ticket"
      jira_ticket=$(echo "$current_branch" | grep -oE "$jira_pattern")
      print_color yellow "Fetching summary via jira CLI..."
      summary=$(jira issue view "$jira_ticket" --plain | grep '^Summary:' | sed 's/^Summary: //')
      if [[ -n "$summary" ]]; then
        clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
        new_branch="${jira_ticket}-${clean_summary}"
        if [[ "$current_branch" == "$new_branch" ]]; then
          print_color green "Branch name already matches desired format. No changes made."
          exit 0
        fi
        git -C "$repo_root" branch -m "$new_branch"
        print_color green "Branch renamed to: $new_branch"
      else
        print_color red "Could not fetch summary. No changes made."
      fi
      exit 0
    fi
    print_color cyan "Enter new branch name or JIRA ticket (e.g., ABC-123): "
    read -r input
    if [[ -z "$input" ]]; then
      print_color red "No input provided. Aborting."
      exit 1
    fi
    if [[ "$input" =~ $jira_pattern ]]; then
      require_tool jira
      print_color yellow "JIRA ticket detected. Fetching summary via jira CLI..."
      summary=$(jira issue view "$input" --plain | grep '^Summary:' | sed 's/^Summary: //')
      if [[ -n "$summary" ]]; then
        clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
        new_branch="${input}-${clean_summary}"
      else
        new_branch="$input"
      fi
    else
      new_branch="$input"
    fi
    git -C "$repo_root" branch -m "$new_branch"
    print_color green "Branch renamed to: $new_branch"
    ;;
  *)
    usage
    ;;
esac
