#!/bin/zsh
# create_worktree.sh - Create a new git worktree with branch naming conventions
# Usage: zsh create_worktree.sh

set -e

autoload -U colors && colors

PROGRAMMING_DIR="$HOME/Programming"
WORKTREES_DIR="$HOME/Worktrees"
mkdir -p "$WORKTREES_DIR"

function require_tool() {
  if ! command -v "$1" &>/dev/null; then
    print -P "%F{red}Error: Required tool '$1' not found.%f"
    exit 1
  fi
}
require_tool git
require_tool fzf

# Slugify function for branch names
slugify() {
  local input="$1"
  echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Select project folder interactively
cd "$PROGRAMMING_DIR" || exit 1
local proj
proj=$(ls -d */ | sed 's#/##' | sort | fzf --prompt="Select project folder: ")
if [[ -z "$proj" || ! -d "$PROGRAMMING_DIR/$proj" ]]; then
  print -P "%F{red}No valid project selected.%f"
  exit 1
fi
repo_dir="$PROGRAMMING_DIR/$proj"
repo_name="$proj"

# Fetch develop branch
cd "$repo_dir" || exit 1
git fetch origin develop || print -P "%F{yellow}Warning: Could not fetch 'develop' branch.%f"

# Select change type
types=(ci build docs feat perf refactor style test fix revert)
emojis=("👷" "📦" "📚" "✨" "🚀" "🔨" "💎" "🧪" "🐛" "⏪")
local prefix emoji
local type_sel
type_sel=$(printf "%s\n" "${types[@]}" | fzf --prompt="Select change type: ")
if [[ -z "$type_sel" ]]; then
  print -P "%F{red}No change type selected.%f"
  exit 1
fi
for i in {1..${#types[@]}}; do
  if [[ "$type_sel" == "${types[$((i - 1))]}" ]]; then
    prefix="$type_sel"
    emoji="${emojis[$((i - 1))]}"
    break
  fi
done

# Ask for Jira ticket
local jira_key summary branch_name summary_commit commit_title description
if
  print -P "%F{cyan}Do you have a Jira ticket? (y/n): %f"
  read -r has_jira && [[ "$has_jira" =~ ^[Yy]$ ]]
then
  require_tool jira
  require_tool jq
  print -P "%F{cyan}Enter Jira ticket number (e.g. SB-1234): %f"
  read -r jira_key
  if [[ -z "$jira_key" ]]; then
    print -P "%F{red}No Jira key entered.%f"
    exit 1
  fi
  summary=$(jira issue view "$jira_key" --raw | jq -r '.fields.summary')
  if [[ -z "$summary" ]]; then
    print -P "%F{red}Could not fetch summary for $jira_key.%f"
    exit 1
  fi
  jira_key_low=$(echo "$jira_key" | tr '[:upper:]' '[:lower:]')
  slug=$(slugify "$summary")
  branch_name="${prefix}/${jira_key_low}_${slug}"
  summary_commit=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | sed 's/  */ /g')
  jira_key_up=$(echo "$jira_key" | tr '[:lower:]' '[:upper:]')
  commit_title="${prefix}: ${emoji} ${jira_key_up} ${summary_commit}"
else
  print -P "%F{cyan}Enter branch slug (lowercase, hyphens, e.g., my-feature): %f"
  read -r slug
  if [[ -z "$slug" ]]; then
    print -P "%F{red}Slug cannot be empty.%f"
    exit 1
  fi
  branch_name="${prefix}/$(slugify "$slug")"
  summary_commit=$(echo "$slug" | tr '-' ' ')
  commit_title="${prefix}: ${emoji} ${summary_commit}"
fi

# Create worktree
worktree_path="$WORKTREES_DIR/$(echo "$branch_name" | tr '/' '_')"
if git worktree add -b "$branch_name" "$worktree_path"; then
  cd "$worktree_path" || exit 1
  print -P "%F{green}Changed directory to $worktree_path%f"
else
  print -P "%F{red}Failed to create worktree. It may already exist.%f"
  exit 1
fi

# Detect and run package manager install
local pm
if [[ -f pnpm-lock.yaml ]]; then
  pm="pnpm"
elif [[ -f package-lock.json ]]; then
  pm="npm"
elif [[ -f yarn.lock ]]; then
  pm="yarn"
fi
if [[ -n "$pm" ]]; then
  print -P "%F{cyan}Running $pm install...%f"
  "$pm" install
else
  print -P "%F{yellow}No supported lockfile (pnpm-lock.yaml, package-lock.json, yarn.lock) found.%f"
fi

# Prepare commit message
if [[ -n "$jira_key" ]]; then
  if [[ -z "$ORG_JIRA_TICKET_LINK" ]]; then
    print -P "%F{yellow}Warning: ORG_JIRA_TICKET_LINK environment variable is not set.%f"
    description=""
  else
    description="Jira: ${ORG_JIRA_TICKET_LINK}${jira_key}"
  fi
fi

# Create empty commit
git commit --allow-empty -m "$commit_title" ${description:+-m "$description"}

print -P "%F{green}Worktree created successfully at: $worktree_path%f"
print -P "%F{green}Branch: $branch_name%f"
[removed code]
