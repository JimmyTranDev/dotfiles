#!/bin/zsh
# utility.sh - Common reusable functions for dotfiles scripts

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
