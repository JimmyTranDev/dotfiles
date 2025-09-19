#!/bin/zsh
# Script to rename current worktree branch with custom name or JIRA ticket

set -e

current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "Current branch: $current_branch"

# Check if current branch already contains a JIRA ticket
jira_pattern='^[A-Z]+-[0-9]+'
if [[ "$current_branch" =~ $jira_pattern ]]; then
  jira_ticket=$(echo "$current_branch" | grep -oE "$jira_pattern")
  echo "Branch already contains JIRA ticket: $jira_ticket"
  echo "Fetching summary via jira CLI..."
  summary=$(jira issue view "$jira_ticket" --plain | grep '^Summary:' | sed 's/^Summary: //')
  if [[ -n "$summary" ]]; then
    clean_summary=$(echo "$summary" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//')
    new_branch="${jira_ticket}-${clean_summary}"
    if [[ "$current_branch" == "$new_branch" ]]; then
      echo "Branch name already matches desired format. No changes made."
      exit 0
    fi
    git branch -m "$new_branch"
    echo "Branch renamed to: $new_branch"
  else
    echo "Could not fetch summary. No changes made."
  fi
  exit 0
fi

echo "Enter new branch name or JIRA ticket (e.g., ABC-123):"
read -r input

if [[ -z "$input" ]]; then
  echo "No input provided. Aborting."
  exit 1
fi

if [[ "$input" =~ $jira_pattern ]]; then
  echo "JIRA ticket detected. Fetching summary via jira CLI..."
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

git branch -m "$new_branch"
echo "Branch renamed to: $new_branch"
