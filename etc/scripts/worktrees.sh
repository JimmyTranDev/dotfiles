#!/bin/zsh
# worktrees.sh - Unified worktree management script
# Usage: zsh worktrees.sh <create|delete|clean|rename> [args]

set -e

# Source utility functions
source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

# --- Reusable Functions ---

# Print colored message
function print_color() {
  local color="$1"; shift
  print -P "%F{$color}$*%f"
}

# Prompt for input with color
function prompt_input() {
  local color="$1"; shift
  print -P "%F{$color}$*%f"
  read -r input
  echo "$input"
}

# Select from list using fzf
function select_fzf() {
  local prompt="$1"; shift
  if [[ $# -gt 0 ]]; then
    printf "%s\n" "$@" | fzf --prompt="$prompt"
  else
    fzf --prompt="$prompt"
  fi
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

# Remove worktree and branch
function remove_worktree_and_branch() {
  local repo="$1" worktree_path="$2" branch_name="$3"
  git -C "$repo" worktree remove "$worktree_path"
  git -C "$repo" branch -d "$branch_name"
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
    local last_proj_file="$HOME/.last_project"
    local last_proj=""
    if [[ -f "$last_proj_file" ]]; then
      last_proj=$(<"$last_proj_file")
    fi
    local all_projects
    all_projects=($(ls -d "$PROGRAMMING_DIR"/*/ | sed "s#$PROGRAMMING_DIR/##;s#/##" | sort))
    local projects_list=()
    if [[ -n "$last_proj" ]]; then
      for p in "${all_projects[@]}"; do
        if [[ "$p" == "$last_proj" ]]; then
          projects_list=("$p")
        fi
      done
      for p in "${all_projects[@]}"; do
        if [[ "$p" != "$last_proj" ]]; then
          projects_list+=("$p")
        fi
      done
    else
      projects_list=("${all_projects[@]}")
    fi
    proj=$(select_fzf "Select project folder: " "${projects_list[@]}")
    if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
      print_color red "No valid project selected."
      exit 1
    fi
    echo "$proj" > "$last_proj_file"
    repo_dir="$PROGRAMMING_DIR/$proj"
    git -C "$repo_dir" fetch origin
    remote_branches=( $(git -C "$repo_dir" branch -r | grep '^  origin/' | sed 's/^  origin\///' | grep -vE '^HEAD$' | sort) )
    if [[ ${#remote_branches[@]} -eq 0 ]]; then
      print_color red "No remote branches found."
      exit 1
    fi
    branch_sel=$(select_fzf "Select remote branch to checkout: " "${remote_branches[@]}")
    if [[ -z "$branch_sel" ]]; then
      print_color red "No branch selected."
      exit 1
    fi
    local_branch="$branch_sel"
    if git -C "$repo_dir" show-ref --verify --quiet "refs/heads/$local_branch"; then
      print_color yellow "Local branch '$local_branch' already exists."
    else
      git -C "$repo_dir" checkout -b "$local_branch" "origin/$branch_sel"
      print_color green "Checked out '$local_branch' tracking 'origin/$branch_sel'."
    fi
    print_color cyan "Do you want to create a worktree for this branch? (y/n): "
    read -r create_wt
    if [[ "$create_wt" =~ ^[Yy]$ ]]; then
      mkdir -p "$WORKTREES_DIR"
      worktree_path="$WORKTREES_DIR/$(echo "$local_branch" | tr '/' '_')"
      if git -C "$repo_dir" worktree add "$worktree_path" "$local_branch"; then
        print_color green "Worktree created at: $worktree_path"
        cd "$worktree_path" || print_color yellow "Warning: Could not cd to $worktree_path."
      else
        print_color red "Failed to create worktree. It may already exist."
      fi
    fi
    ;;
  create)
    require_tool git
    require_tool fzf
    mkdir -p "$WORKTREES_DIR"
    local proj
    local last_proj_file="$HOME/.last_project"
    local last_proj=""
    if [[ -f "$last_proj_file" ]]; then
      last_proj=$(<"$last_proj_file")
    fi
    local all_projects
    all_projects=($(ls -d "$PROGRAMMING_DIR"/*/ | sed "s#$PROGRAMMING_DIR/##;s#/##" | sort))
    local projects_list=()
    if [[ -n "$last_proj" ]]; then
      for p in "${all_projects[@]}"; do
        if [[ "$p" == "$last_proj" ]]; then
          projects_list=("$p")
        fi
      done
      for p in "${all_projects[@]}"; do
        if [[ "$p" != "$last_proj" ]]; then
          projects_list+=("$p")
        fi
      done
    else
      projects_list=("${all_projects[@]}")
    fi
    proj=$(select_fzf "Select project folder: " "${projects_list[@]}")
    if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
      print_color red "No valid project selected."
      exit 1
    fi
    echo "$proj" > "$last_proj_file"
    repo_dir="$PROGRAMMING_DIR/$proj"
    git -C "$repo_dir" fetch origin develop || print_color yellow "Warning: Could not fetch 'develop' branch."
    types=(ci build docs feat perf refactor style test fix revert)
    emojis=("👷" "📦" "📚" "✨" "🚀" "🔨" "💎" "🧪" "🐛" "⏪")
    local prefix emoji
    type_sel=$(select_fzf "Select change type: " "${types[@]}")
    if [[ -z "$type_sel" ]]; then
      print_color red "No change type selected."
      exit 1
    fi
    for i in {1..${#types[@]}}; do
      if [[ "$type_sel" == "${types[$((i - 1))]}" ]]; then
        prefix="$type_sel"
        emoji="${emojis[$((i - 1))]}"
        break
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
      if [[ -z "$jira_key" ]]; then
        print_color red "No Jira key entered."
        exit 1
      fi
      summary=$(jira issue view "$jira_key" --raw | jq -r '.fields.summary')
      if [[ -z "$summary" ]]; then
        print_color red "Could not fetch summary for $jira_key."
        exit 1
      fi
      jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
      slug=$(slugify "$summary")
      branch_name="${prefix}/${jira_key_low}_${slug}"
      summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
      jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
      commit_title="${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
    else
      print_color cyan "Enter branch slug (lowercase, hyphens, e.g., my-feature): "
      read -r slug
      if [[ -z "$slug" ]]; then
        print_color red "Slug cannot be empty."
        exit 1
      fi
      branch_name="${prefix}/$(slugify "$slug")"
      summary_commit=$(echo "$slug" | tr '-' ' ')
      commit_title="${prefix}: ${emoji} ${summary_commit}"
    fi
    worktree_path="$WORKTREES_DIR/$(echo "$branch_name" | tr '/' '_')"
    if git -C "$repo_dir" worktree add -b "$branch_name" "$worktree_path"; then
      cd "$worktree_path" || print_color yellow "Warning: Could not cd to $worktree_path."
      print_color green "Changed directory to $worktree_path"
    else
      print_color red "Failed to create worktree. It may already exist."
      exit 1
    fi
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
    if [[ $# -eq 1 ]]; then
      WORKTREE_PATH="$1"
    else
      WORKTREE_PATH=$(find "$WORKTREES_DIR" -mindepth 1 -maxdepth 1 -type d | sort | select_fzf "Select a worktree to delete: ")
      if [[ -z "$WORKTREE_PATH" ]]; then
        print_color red "No worktree selected."
        exit 1
      fi
    fi
    if [[ ! -d "$WORKTREE_PATH" ]]; then
      print_color red "Error: Directory $WORKTREE_PATH does not exist."
      exit 1
    fi
    if [[ ! -f "$WORKTREE_PATH/.git" ]]; then
      print_color red "Error: $WORKTREE_PATH does not look like a git worktree (missing .git file)."
      exit 1
    fi
    GITDIR_LINE=$(head -n1 "$WORKTREE_PATH/.git")
    if [[ "$GITDIR_LINE" =~ ^gitdir:\ (.*)$ ]]; then
      WORKTREE_GITDIR="${BASH_REMATCH[1]}"
      MAIN_REPO=$(dirname "$(dirname "$WORKTREE_GITDIR")")
    else
      print_color red "Error: Could not parse .git file in $WORKTREE_PATH"
      exit 1
    fi
    print_color yellow "Main repo detected at: $MAIN_REPO"
    if [[ ! -d "$MAIN_REPO/.git" ]]; then
      print_color yellow "Warning: $MAIN_REPO is not a valid git repository. Skipping git cleanup."
    else
      if git -C "$MAIN_REPO" worktree list | grep -q " $WORKTREE_PATH "; then
        print_color yellow "Removing worktree via git..."
        git -C "$MAIN_REPO" worktree remove "$WORKTREE_PATH"
      else
        print_color yellow "Worktree not listed in git, pruning stale references..."
        git -C "$MAIN_REPO" worktree prune
      fi
    fi
    if [[ -d "$WORKTREE_PATH" ]]; then
      print_color yellow "Deleting directory $WORKTREE_PATH..."
      rm -rf "$WORKTREE_PATH"
    else
      print_color green "Directory $WORKTREE_PATH already deleted."
    fi
    print_color green "✅ Worktree deletion complete."
    ;;
  clean)
    require_tool git
    main_branch="main"
    repo_root=$(git rev-parse --show-toplevel)
    print_color yellow "Scanning for merged worktrees..."
    git -C "$repo_root" worktree list | while read -r line; do
      worktree_path=$(echo "$line" | awk '{print $1}')
      branch_ref=$(echo "$line" | grep -oE ' \[.*\]' | sed 's/\[//;s/\]//')
      branch_name=""
      if [[ "$branch_ref" == refs/heads/* ]]; then
        branch_name=${branch_ref#refs/heads/}
      fi
      if [[ -z "$branch_name" || "$branch_name" == "$main_branch" ]]; then
        continue
      fi
      if git -C "$repo_root" branch --merged "$main_branch" | grep -q "^  $branch_name$"; then
        print_color yellow "Removing merged worktree: $worktree_path (branch: $branch_name)"
        git -C "$repo_root" worktree remove "$worktree_path"
        git -C "$repo_root" branch -d "$branch_name"
      fi
    done
    print_color green "Done removing merged worktrees."
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
