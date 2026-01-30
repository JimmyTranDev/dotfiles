#!/bin/bash

set -e

get_commits() {
    git log --oneline -n 50 --pretty=format:"%h %s"
}

if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository"
    exit 1
fi

if ! command -v fzf &> /dev/null; then
    echo "Error: fzf is required but not installed"
    exit 1
fi

echo "Select the first commit (older):"
COMMIT1=$(get_commits | fzf --height=20 --reverse --prompt="First commit > " | awk '{print $1}')

if [ -z "$COMMIT1" ]; then
    echo "No commit selected"
    exit 1
fi

echo "Select the second commit (newer) or press Enter for HEAD:"
COMMIT2=$(get_commits | fzf --height=20 --reverse --prompt="Second commit (Enter for HEAD) > " --print-query | tail -1 | awk '{print $1}')

if [ -z "$COMMIT2" ]; then
    COMMIT2="HEAD"
fi

echo ""
echo "Showing diff between $COMMIT1 and $COMMIT2"
echo "----------------------------------------"

git diff "$COMMIT1" "$COMMIT2"
