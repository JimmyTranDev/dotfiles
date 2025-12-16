#!/bin/zsh
# ===================================================================
# jira.sh - JIRA Integration Functions
# ===================================================================

# JIRA Integration Functions
# Note: Depends on core.sh functions being available

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

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
  
  print_color blue "Fetching JIRA ticket: $jira_key" >&2
  
  local jira_raw
  if ! jira_raw=$(jira issue view "$jira_key" --raw 2>&1); then
    print_color red "Failed to fetch JIRA ticket: $jira_key" >&2
    print_color red "Error output: $jira_raw" >&2
    return 1
  fi
  
  if [[ -z "$jira_raw" ]]; then
    print_color red "Empty response from JIRA CLI for ticket: $jira_key" >&2
    return 1
  fi
  
  # Check if the response is valid JSON
  if ! echo "$jira_raw" | jq . >/dev/null 2>&1; then
    print_color red "Invalid JSON response from JIRA CLI" >&2
    print_color red "Response: $jira_raw" >&2
    return 1
  fi
  
  local summary
  if ! summary=$(echo "$jira_raw" | jq -r '.fields.summary' 2>/dev/null); then
    print_color red "Failed to parse JIRA response for: $jira_key" >&2
    print_color red "Raw response: $jira_raw" >&2
    return 1
  fi
  
  if [[ -z "$summary" || "$summary" == "null" ]]; then
    print_color red "Could not extract summary from JIRA ticket: $jira_key" >&2
    print_color red "Summary field value: '$summary'" >&2
    return 1
  fi
  
  print_color blue "Successfully extracted summary: $summary" >&2
  echo "$summary"
}

# Format branch name
format_branch_name() {
  local prefix="$1" jira_key="$2" summary="$3"
  
  if [[ -z "$prefix" ]]; then
    print_color red "Error: Prefix is required for branch name formatting"
    return 1
  fi
  
  if [[ -z "$jira_key" ]]; then
    print_color red "Error: JIRA key is required for branch name formatting"
    return 1
  fi
  
  if [[ -z "$summary" ]]; then
    print_color red "Error: Summary is required for branch name formatting"
    return 1
  fi
  
  local jira_key_low slug
  jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
  
  # Use the slugify function from utility.sh
  if ! slug=$(slugify "$summary"); then
    print_color red "Error: Failed to slugify summary: $summary"
    return 1
  fi
  
  if [[ -z "$slug" ]]; then
    print_color red "Error: Slugified summary is empty"
    return 1
  fi
  
  local branch_name="${prefix}/${jira_key_low}_${slug}"
  print_color blue "Generated branch name: $branch_name"
  echo "$branch_name"
}

# Format commit title
format_commit_title() {
  local prefix="$1" emoji="$2" jira_key="$3" summary="$4"
  
  if [[ -z "$prefix" ]]; then
    print_color red "Error: Prefix is required for commit title formatting"
    return 1
  fi
  
  if [[ -z "$emoji" ]]; then
    print_color red "Error: Emoji is required for commit title formatting"
    return 1
  fi
  
  if [[ -z "$jira_key" ]]; then
    print_color red "Error: JIRA key is required for commit title formatting"
    return 1
  fi
  
  if [[ -z "$summary" ]]; then
    print_color red "Error: Summary is required for commit title formatting"
    return 1
  fi
  
  local jira_key_up summary_commit
  jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
  summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
  
  local commit_title="${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
  print_color blue "Generated commit title: $commit_title"
  echo "$commit_title"
}

# Validate JIRA key format
validate_jira_key() {
  local jira_key="$1"
  
  if [[ ! "$jira_key" =~ $JIRA_PATTERN ]]; then
    print_color yellow "Warning: JIRA key '$jira_key' doesn't match expected format (e.g., SB-1234)"
    print_color cyan "Continue anyway? (y/n): "
    read -r continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy]$ ]]; then
      return 1
    fi
  fi
  return 0
}

# Process JIRA ticket for worktree creation
process_jira_ticket() {
  local prefix="$1" emoji="$2"
  
  print_color cyan "Enter Jira ticket number (e.g. SB-1234): "
  read -r jira_key
  
  if [[ -z "$jira_key" ]]; then
    print_color red "No Jira key entered."
    return 1
  fi
  
  # Validate JIRA key format
  if ! validate_jira_key "$jira_key"; then
    print_color yellow "Operation cancelled."
    return 1
  fi
  
  print_color yellow "Fetching Jira ticket details for $jira_key..."
  
  local summary
  if ! summary=$(get_jira_summary "$jira_key"); then
    print_color red "Failed to get JIRA summary. You can:"
    print_color yellow "  1. Continue with manual entry (recommended)"
    print_color yellow "  2. Exit and fix JIRA configuration"
    print_color cyan "Continue with manual entry? (y/n): "
    read -r continue_manual
    if [[ "$continue_manual" =~ ^[Yy]$ ]]; then
      return 2  # Signal to fall back to manual entry
    else
      print_color yellow "Operation cancelled."
      return 1
    fi
  fi
  
  if [[ -z "$summary" ]]; then
    print_color red "Empty summary returned from JIRA"
    return 1
  fi
  
  print_color green "Found: $summary"
  
  local branch_name commit_title folder_name jira_key_up slug description
  
  if ! branch_name=$(format_branch_name "$prefix" "$jira_key" "$summary"); then
    print_color red "Failed to format branch name"
    return 1
  fi
  
  if ! commit_title=$(format_commit_title "$prefix" "$emoji" "$jira_key" "$summary"); then
    print_color red "Failed to format commit title"
    return 1
  fi
  
  jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
  
  if ! slug=$(slugify "$summary"); then
    print_color red "Failed to create slug from summary"
    return 1
  fi
  
  folder_name="${jira_key_up}_${slug}"
  print_color blue "Folder name: $folder_name"
  
  # Set description with JIRA link if available
  if [[ -n "$ORG_JIRA_TICKET_LINK" ]]; then
    description="Jira: ${ORG_JIRA_TICKET_LINK}${jira_key}"
  else
    print_color yellow "Warning: ORG_JIRA_TICKET_LINK environment variable is not set."
    description=""
  fi
  
  # Export results for caller
  export JIRA_BRANCH_NAME="$branch_name"
  export JIRA_COMMIT_TITLE="$commit_title"
  export JIRA_FOLDER_NAME="$folder_name"
  export JIRA_DESCRIPTION="$description"
  
  return 0
}

# Clean JIRA summary for use in branch names
clean_jira_summary() {
  local summary="$1"
  echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Create branch name from JIRA ticket
create_branch_from_jira() {
  local jira_ticket="$1"
  
  if [[ -z "$jira_ticket" ]]; then
    print_color red "Error: JIRA ticket is required"
    return 1
  fi
  
  local summary
  summary=$(get_jira_summary "$jira_ticket" 2>/dev/null)
  
  if [[ $? -eq 0 && -n "$summary" ]]; then
    local clean_summary
    clean_summary=$(clean_jira_summary "$summary")
    echo "${jira_ticket}-${clean_summary}"
  else
    # Fallback to just the ticket number
    echo "$jira_ticket"
  fi
}
