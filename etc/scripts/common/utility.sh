#!/bin/zsh
# utility.sh - Common reusable functions for dotfiles scripts

set -e

autoload -U colors && colors

require_tool() {
  if ! command -v "$1" &>/dev/null; then
    print -P "%F{red}Error: Required tool '$1' not found.%f"
    exit 1
  fi
}

slugify() {
  local input="$1"
  echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}
