#!/bin/zsh
# ===================================================================
# create.sh - Create Worktree Command
# ===================================================================

# Log commit history to notes
log_commit_history() {
  local commit_message="$1"
  local notes_dir="$HOME/Programming/notes.md"
  
  # Skip logging for notes.md files
  if [[ "$commit_message" == *"notes.md"* ]]; then
    return 0
  fi
  
  # Get date information
  local current_week=$(date +%V)
  local current_year=$(date +%Y)
  local short_date=$(date +%d.%m.%Y)
  local day_name=$(date +%A)
  
  # Format log structure
  local title="# Week $current_week, $current_year"
  local day_title="## $day_name ($short_date)"
  local log_file="$current_year-$current_week.md"
  
  # Get repository name from current directory
  local repo_name=$(basename "$(git rev-parse --show-toplevel 2>/dev/null)" 2>/dev/null)
  if [[ -z "$repo_name" ]]; then
    repo_name="unknown"
  fi
  
  local log_dir="$notes_dir/$repo_name"
  local log_file_path="$log_dir/$log_file"
  
  # Create log directory if it doesn't exist
  mkdir -p "$log_dir"
  
  # Create or update log file
  if [[ ! -f "$log_file_path" ]]; then
    # Create new file with title, day title, and message
    cat > "$log_file_path" << EOF
$title

$day_title
$commit_message  
EOF
  else
    # Read existing file and check for title and day sections
    local has_title=false
    local has_day=false
    
    while IFS= read -r line; do
      if [[ "$line" == "$title" ]]; then
        has_title=true
      fi
      if [[ "$line" == "$day_title" ]]; then
        has_day=true
      fi
      if [[ "$has_title" == true && "$has_day" == true ]]; then
        break
      fi
    done < "$log_file_path"
    
    # Add missing sections and append message
    if [[ "$has_title" == false ]]; then
      echo "$title" >> "$log_file_path"
    fi
    
    if [[ "$has_day" == false ]]; then
      if [[ -s "$log_file_path" ]]; then
        echo "" >> "$log_file_path"
      fi
      echo "$day_title" >> "$log_file_path"
    fi
    
    echo "$commit_message  " >> "$log_file_path"
  fi
  
  # Auto-commit and push to notes repository
  if [[ -d "$notes_dir/.git" ]]; then
    print_color yellow "📝 Updating programming log..."
    
    # Change to notes directory for git operations
    (
      cd "$notes_dir" || return 1
      
      # Pull latest changes
      git pull --no-rebase >/dev/null 2>&1
      
      # Add all changes
      git add . >/dev/null 2>&1
      
      # Commit with no-verify to skip hooks
      git commit --no-verify -m "feat: ✨ update" >/dev/null 2>&1
      
      # Push changes
      git push >/dev/null 2>&1
    )
    
    print_color green "✅ Log entry added to $log_file"
  else
    print_color yellow "📝 Log entry added to $log_file (no git repo for auto-sync)"
  fi
}

# Create worktree subcommand
cmd_create() {
  if ! check_tool git; then
    return 1
  fi
  
  if ! check_tool fzf; then
    return 1
  fi
  
  local jira_ticket="$1"
  local repo_name="$2"
  
  # Get repository first - either by name or interactive selection
  local main_repo
  if [[ -n "$repo_name" ]]; then
    print_color yellow "Looking for repository: $repo_name"
    main_repo=$(get_repository "$repo_name") || {
      print_color red "Error: Could not find repository '$repo_name'"
      return 1
    }
  else
    main_repo=$(get_repository) || {
      print_color red "Error: Repository selection failed"
      return 1
    }
  fi
  
  print_color yellow "Using repository: $(basename "$main_repo")"
  print_color yellow "Repository path: $main_repo"
  
  # Get the main branch for the selected repository
  local main_branch
  main_branch=$(find_main_branch "$main_repo") || {
    print_color red "Error: Could not find main branch in $main_repo"
    return 1
  }
  
  print_color yellow "Base branch: $main_branch"
  
  # Now prompt for JIRA ticket if not provided
  if [[ -z "$jira_ticket" ]]; then
    print_color cyan "Enter JIRA ticket (e.g., ABC-123) or leave empty to skip JIRA integration:"
    read -r jira_ticket
  fi
  
  local branch_name=""
  local summary=""
  
  # Try to get JIRA summary if ticket provided
  if [[ -n "$jira_ticket" && "$jira_ticket" =~ $JIRA_PATTERN ]]; then
    if ! check_tool jira; then
      print_color yellow "JIRA CLI not available. Proceeding without JIRA integration."
      branch_name="$jira_ticket"
    else
      print_color yellow "Fetching JIRA ticket details..."
      
      # Capture only the summary, redirect status messages to stderr
      summary=$(get_jira_summary "$jira_ticket" 2>/dev/null)
      if [[ $? -eq 0 && -n "$summary" ]]; then
        print_color green "✅ JIRA ticket found: $summary"
        # Clean the summary thoroughly - remove any stray output and normalize
        local clean_summary
        clean_summary=$(echo "$summary" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
        branch_name="${jira_ticket}-${clean_summary}"
      else
        print_color yellow "Could not fetch JIRA summary. Using ticket number as branch name."
        branch_name="$jira_ticket"
      fi
    fi
  elif [[ -n "$jira_ticket" ]]; then
    # User provided something that's not a JIRA ticket
    branch_name="$jira_ticket"
    print_color yellow "Input doesn't match JIRA pattern. Using as branch name directly."
  else
    # No input provided
    print_color cyan "Enter branch name:"
    read -r branch_name
    
    if [[ -z "$branch_name" ]]; then
      print_color red "No branch name provided. Aborting."
      return 1
    fi
  fi
  
  # Ensure we have a clean branch name
  # Strip any remaining artifacts and sanitize thoroughly
  # Keep the original input for commit message
  local original_input="$branch_name"
  branch_name=$(echo "$branch_name" | head -1 | sed 's/\x1b\[[0-9;]*m//g' | tr -d '\n\r' | sed 's/[^a-zA-Z0-9._-]/-/g; s/--*/-/g; s/^-//; s/-$//')
  
  if [[ -z "$branch_name" ]]; then
    print_color red "Invalid branch name. Aborting."
    return 1
  fi
  
  print_color cyan "Creating worktree for branch: $branch_name"
  
  # Prompt for commit type selection
  print_color cyan "Select commit type:"
  local commit_types=("feat" "fix" "docs" "style" "refactor" "test" "chore" "revert" "build" "ci" "perf")
  local commit_type
  
  if check_tool fzf; then
    commit_type=$(printf '%s\n' "${commit_types[@]}" | fzf --prompt="Select commit type: " --height=40% --reverse)
  else
    # Fallback to manual selection if fzf is not available
    echo "Available commit types:"
    for i in "${!commit_types[@]}"; do
      echo "$((i+1)). ${commit_types[$i]}"
    done
    echo -n "Enter number (1-${#commit_types[@]}) or type name [default: feat]: "
    read -r selection
    
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le "${#commit_types[@]}" ]]; then
      commit_type="${commit_types[$((selection-1))]}"
    elif [[ -n "$selection" ]]; then
      commit_type="$selection"
    else
      commit_type="feat"
    fi
  fi
  
  # Default to feat if no selection made
  if [[ -z "$commit_type" ]]; then
    commit_type="feat"
  fi
  
  print_color green "Selected commit type: $commit_type"
  
  # Create worktree directory path (using just the branch name)
  local worktree_dir="$WORKTREES_DIR/$branch_name"
  
  # Check if worktree directory already exists
  if [[ -d "$worktree_dir" ]]; then
    print_color red "Error: Worktree directory already exists: $worktree_dir"
    return 1
  fi
  
  # Ensure worktrees directory exists
  mkdir -p "$WORKTREES_DIR" || {
    print_color red "Error: Could not create worktrees directory: $WORKTREES_DIR"
    return 1
  }
  
  print_color yellow "Creating worktree at: $worktree_dir"
  
  # Create and switch to the new worktree
  git -C "$main_repo" worktree add -b "$branch_name" "$worktree_dir" "$main_branch" || {
    print_color red "Error: Failed to create worktree"
    return 1
  }
  
  print_color green "✅ Worktree created successfully!"
  print_color cyan "📁 Path: $worktree_dir"
  print_color cyan "🌿 Branch: $branch_name"
  
  # Create an empty initial commit with the branch name and JIRA link if available
  print_color yellow "Creating initial commit..."
  local commit_message
  
  # Map commit types to emojis
  local emoji
  case "$commit_type" in
    "feat")     emoji="✨" ;;
    "fix")      emoji="🐛" ;;
    "docs")     emoji="📚" ;;
    "style")    emoji="💎" ;;
    "refactor") emoji="🔨" ;;
    "test")     emoji="🧪" ;;
    "chore")    emoji="🔧" ;;
    "revert")   emoji="⏪" ;;
    "build")    emoji="📦" ;;
    "ci")       emoji="👷" ;;
    "perf")     emoji="🚀" ;;
    *)          emoji="✨" ;;  # Default fallback
  esac

  # Format commit message based on whether we have JIRA info
  if [[ -n "$jira_ticket" && "$jira_ticket" =~ $JIRA_PATTERN ]]; then
    if [[ -n "$summary" ]]; then
      # Use the JIRA summary for a descriptive commit message
      commit_message="$commit_type: $emoji $jira_ticket $summary"
    else
      # Just use the ticket number
      commit_message="$commit_type: $emoji $jira_ticket"
    fi
    
    # Add JIRA link in the commit body
    commit_message="$commit_message

Jira: $jira_ticket"
  else
    # No JIRA ticket, use the original input message
    commit_message="$commit_type: $emoji $original_input"
  fi
  
  git -C "$worktree_dir" commit --allow-empty -m "$commit_message" || {
    print_color yellow "Warning: Could not create initial commit"
  }
  
  # Log the commit to programming notes
  if [[ $? -eq 0 ]]; then
    (cd "$worktree_dir" && log_commit_history "$commit_message")
  fi
  
  if [[ -n "$summary" ]]; then
    print_color cyan "📋 JIRA: $jira_ticket - $summary"
  fi
  
  
  # Install dependencies if package.json exists
  if [[ -f "$worktree_dir/package.json" ]]; then
    print_color yellow "📦 Package.json found. Installing dependencies..."
    
    # Change to worktree directory for dependency installation
    cd "$worktree_dir" || {
      print_color yellow "Warning: Could not navigate to worktree directory for dependency installation"
    }
    
    local package_manager
    package_manager=$(detect_package_manager)
    
    if [[ -n "$package_manager" ]]; then
      print_color cyan "Using package manager: $package_manager"
      
      case "$package_manager" in
        "pnpm")
          if command -v pnpm >/dev/null 2>&1; then
            pnpm install
          else
            print_color yellow "pnpm not found, falling back to npm"
            npm install
          fi
          ;;
        "yarn")
          if command -v yarn >/dev/null 2>&1; then
            yarn install
          else
            print_color yellow "yarn not found, falling back to npm"
            npm install
          fi
          ;;
        "npm"|*)
          npm install
          ;;
      esac
    else
      print_color yellow "No lock file found, using npm"
      npm install
    fi
  else
    print_color cyan "No package.json found, skipping dependency installation"
    # Still navigate to the worktree directory
    cd "$worktree_dir" || {
      print_color yellow "Warning: Could not navigate to worktree directory"
    }
  fi
  
  print_color yellow "Now in worktree directory. Happy coding! 🚀"
}
