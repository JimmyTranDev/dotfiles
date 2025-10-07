#!/bin/zsh
# ===================================================================
# create.sh - Create Worktree Command
# ===================================================================

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
        clean_summary=$(echo "$summary" | head -1 | sed 's/[0-9]*m//g' | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
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
  branch_name=$(echo "$branch_name" | head -1 | sed 's/[0-9]*m//g' | tr -d '\n\r' | sed 's/[^a-zA-Z0-9._-]/_/g; s/__*/_/g; s/^_//; s/_$//')
  
  if [[ -z "$branch_name" ]]; then
    print_color red "Invalid branch name. Aborting."
    return 1
  fi
  
  print_color cyan "Creating worktree for branch: $branch_name"
  
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
  local commit_message="$branch_name"
  
  # Add JIRA link if we have a valid JIRA ticket
  if [[ -n "$jira_ticket" && "$jira_ticket" =~ $JIRA_PATTERN ]]; then
    commit_message="$branch_name

Jira: ${ORG_JIRA_TICKET_LINK}${jira_ticket}"
  fi
  
  git -C "$worktree_dir" commit --allow-empty -m "$commit_message" || {
    print_color yellow "Warning: Could not create initial commit"
  }
  
  if [[ -n "$summary" ]]; then
    print_color cyan "📋 JIRA: $jira_ticket - $summary"
  fi
  
  # Navigate to the new worktree
  cd "$worktree_dir" || {
    print_color yellow "Warning: Could not navigate to worktree directory"
    return 0
  }
  
  # Install dependencies if package.json exists
  if [[ -f "package.json" ]]; then
    print_color yellow "📦 Package.json found. Installing dependencies..."
    
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
  fi
  
  print_color yellow "Now in worktree directory. Happy coding! 🚀"
}
