#!/bin/zsh
# ===================================================================
# config.sh - Worktrees Configuration
# ===================================================================

# Global configuration
export WORKTREES_DIR="$HOME/Worktrees"
export PROGRAMMING_DIR="$HOME/Programming"

# Change types and their corresponding emojis
export WORKTREE_TYPES=(ci build docs feat perf refactor style test fix revert)
export WORKTREE_EMOJIS=("👷" "📦" "📚" "✨" "🚀" "🔨" "💎" "🧪" "🐛" "⏪")

# JIRA configuration
export JIRA_PATTERN='^[A-Z]+-[0-9]+'
