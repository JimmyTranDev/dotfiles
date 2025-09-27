#!/bin/bash
# utility.sh - Common reusable functions for dotfiles scripts

# Setup colors for both bash and zsh
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U colors && colors
elif [[ -n "$BASH_VERSION" ]]; then
  # Define color variables for bash
  if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
  fi
fi

require_tool() {
  if ! command -v "$1" &>/dev/null; then
    if [[ -n "$ZSH_VERSION" ]]; then
      print -P "%F{red}Error: Required tool '$1' not found.%f"
    else
      echo -e "${RED}Error: Required tool '$1' not found.${NC}"
    fi
    exit 1
  fi
}

slugify() {
  local input="$1"
  echo "$input" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

fzf_select_and_cd() {
  local prompt="$1"
  local base_dir="$2"
  local last_file="$3"
  local open_cmd="$4"
  shift 4
  local items=("$@")
  local last_sel=""
  [[ -f "$last_file" ]] && last_sel=$(<"$last_file")
  local sorted_items=()
  if [[ -n "$last_sel" ]]; then
    for i in "${items[@]}"; do
      if [[ "$i" == "$last_sel" ]]; then
        sorted_items=("$i")
      fi
    done
    for i in "${items[@]}"; do
      if [[ "$i" != "$last_sel" ]]; then
        sorted_items+=("$i")
      fi
    done
  else
    sorted_items=("${items[@]}")
  fi
  local selected
  selected=$(printf "%s\n" "${sorted_items[@]}" | fzf --prompt="$prompt")
  if [[ -n "$selected" ]]; then
    echo "$selected" > "$last_file"
    cd "$base_dir/$selected"
    [[ -n "$open_cmd" ]] && eval "$open_cmd"
  else
    echo "No selection."
    return 1
  fi
}
