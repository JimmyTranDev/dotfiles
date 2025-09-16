#!/bin/bash

set -e

# Directories
PROGRAMMING_DIR="$HOME/Programming"
WORKTREES_DIR="$HOME/Worktrees"
mkdir -p "$WORKTREES_DIR"

# Slugify function for branch names
slugify() {
  local input="$1"
  echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9[:space:]]\+/-/g' | tr -s ' ' | sed 's/ /-/g' | sed 's/-$//' | sed 's/^-*//' | sed 's/--*/-/g'
}

# Select project folder
cd "$PROGRAMMING_DIR" || exit 1
PS3="Select project folder: "
select proj in */; do
  if [[ -n $proj && -d "$PROGRAMMING_DIR/$proj" ]]; then
    repo_dir="$PROGRAMMING_DIR/$proj"
    repo_name="${proj%/}"
    break
  fi
  echo "Invalid selection, try again."
done

# Fetch develop branch
cd "$repo_dir" || exit 1
git fetch origin develop

# Select change type
types=("ci" "build" "docs" "feat" "perf" "refactor" "style" "test" "fix" "revert")
emojis=("👷" "📦" "📚" "✨" "🚀" "🔨" "💎" "🧪" "🐛" "⏪")
PS3="Select change type: "
select type_sel in "${types[@]}"; do
  if [[ $REPLY -ge 1 && $REPLY -le ${#types[@]} ]]; then
    prefix="${types[$((REPLY - 1))]}"
    emoji="${emojis[$((REPLY - 1))]}"
    break
  fi
  echo "Invalid selection, try again."
done

# Ask for Jira ticket
read -p "Do you have a Jira ticket? (y/n): " has_jira
jira_key=""
summary_slug=""
commit_title=""

if [[ "$has_jira" =~ ^[Yy]$ ]]; then
  read -p "Enter Jira ticket number (e.g. SB-1234): " jira_key
  if [[ -z "$jira_key" ]]; then
    echo "No Jira key entered."
    exit 1
  fi
  summary=$(jira issue view "$jira_key" --raw | jq -r '.fields.summary')
  # Format branch: fix/bw-9711_prefill-loan-value-in-altinn-data
  jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
  slug=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-')
  branch_name="${prefix}/${jira_key_low}_${slug}"
  summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
  jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
  commit_title="${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
else
  # No Jira, ask for slug
  read -p "Enter branch slug (lowercase, hyphens, e.g., my-feature): " slug
  if [[ -z "$slug" ]]; then
    echo "Slug cannot be empty."
    exit 1
  fi
  branch_name="${prefix}/${slug}"
  summary_slug=$(echo "$slug" | tr '-' ' ')
  commit_title="${prefix}: ${emoji} ${summary_slug}"
fi

# Create worktree
worktree_path="$WORKTREES_DIR/$(echo "$branch_name" | tr '/' '_')"
if git worktree add -b "$branch_name" "$worktree_path"; then
  cd "$worktree_path" || exit 1
  echo "Changed directory to $worktree_path"
else
  echo "Failed to create worktree. It may already exist."
  exit 1
fi

# Detect and run package manager install
pm=""
if [[ -f pnpm-lock.yaml ]]; then
  pm="pnpm"
elif [[ -f package-lock.json ]]; then
  pm="npm"
elif [[ -f yarn.lock ]]; then
  pm="yarn"
fi
if [[ -n "$pm" ]]; then
  "$pm" install
else
  echo "No supported lockfile (pnpm-lock.yaml, package-lock.json, yarn.lock) found."
  exit 1
fi

# Prepare commit message
commit_title="${prefix}: ${emoji}"
if [[ -n "$jira_key" ]]; then
  commit_title+=" ${jira_key} ${summary_slug}"
else
  commit_title+=" ${summary_slug}"
fi
description=""
if [[ -n "$jira_key" ]]; then
  if [[ -z "$ORG_JIRA_TICKET_LINK" ]]; then
    echo "Error: ORG_JIRA_TICKET_LINK environment variable is not set."
    exit 1
  fi
  description="Jira: ${ORG_JIRA_TICKET_LINK}${jira_key}"
fi

# Create empty commit
git commit --allow-empty -m "$commit_title" -m "$description"

echo "Worktree created successfully at: $worktree_path"
echo "Branch: $branch_name"
