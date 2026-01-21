#!/bin/zsh
# ===================================================================
# config.sh - Configuration for Git Worktree Management
# ===================================================================

# Enable PCRE for regex matching to support {n,m} quantifiers
setopt RE_MATCH_PCRE

# Configuration
export WORKTREES_DIR="${WORKTREES_DIR:-$HOME/Programming/Worktrees}"
export PROGRAMMING_DIR="${PROGRAMMING_DIR:-$HOME/Programming}"
export JIRA_PATTERN='^[A-Z]+-[0-9]+$'
