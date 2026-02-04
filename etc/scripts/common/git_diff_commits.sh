#!/bin/bash

set -e

get_commits() {
	git log --oneline -n 50 --pretty=format:"%h %s"
}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
	echo "Error: Not in a git repository"
	exit 1
fi

if ! command -v fzf &>/dev/null; then
	echo "Error: fzf is required but not installed"
	exit 1
fi

echo "Select commit:"
COMMIT=$(get_commits | fzf --height=20 --reverse --prompt="Commit > " | awk '{print $1}')

if [ -z "$COMMIT" ]; then
	echo "No commit selected"
	exit 1
fi

echo ""
echo "Showing diff for $COMMIT"
echo "----------------------------------------"

git show "$COMMIT"
