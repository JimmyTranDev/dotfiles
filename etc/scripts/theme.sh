#!/bin/zsh
# ===================================================================
# theme.sh - Centralized Catppuccin Theme Management Script
# ===================================================================
# 
# A script to manage Catppuccin themes across all dotfiles configurations.
# Supports switching between mocha, latte, frappe, and macchiato variants.
#
# Usage: zsh theme.sh <set|get|list> [theme_name]
#
# Author: Jimmy Tran
# ===================================================================

set -e

# Source utility functions
source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"

# ===================================================================
# CONFIGURATION
# ===================================================================

DOTFILES_DIR="$HOME/Programming/dotfiles"
THEME_CONFIG="$DOTFILES_DIR/etc/theme.conf"
SRC_DIR="$DOTFILES_DIR/src"

# Valid Catppuccin themes
VALID_THEMES=("mocha" "latte" "frappe" "macchiato")

# ===================================================================
# UTILITY FUNCTIONS
# ===================================================================

# Print colored message
print_color() {
  local color="$1"; shift
  print -P "%F{$color}$*%f"
}

# Get current theme from config
get_current_theme() {
  if [[ -f "$THEME_CONFIG" ]]; then
    grep "^CATPPUCCIN_THEME=" "$THEME_CONFIG" | cut -d'"' -f2
  else
    echo "mocha"  # default
  fi
}

# Validate theme name
validate_theme() {
  local theme="$1"
  for valid_theme in "${VALID_THEMES[@]}"; do
    if [[ "$theme" == "$valid_theme" ]]; then
      return 0
    fi
  done
  return 1
}

# Get FZF colors for theme
get_fzf_colors() {
  local theme="$1"
  case "$theme" in
    "mocha")
      echo "--color=bg:#1e1e2e,fg:#cdd6f4,hl:#f38ba8 --color=fg+:#cdd6f4,bg+:#313244,hl+:#f38ba8 --color=info:#89b4fa,prompt:#fab387,spinner:#f9e2af --color=header:#cba6f7,marker:#89dceb --color=border:#6c7086"
      ;;
    "latte")
      echo "--color=bg:#e1e2e7,fg:#4c4f69,hl:#d20f39 --color=fg+:#4c4f69,bg+:#f5e0dc,hl+:#d20f39 --color=info:#1e66f5,prompt:#fe640b,spinner:#df8e1d --color=header:#8839ef,marker:#179299 --color=border:#dce0e8"
      ;;
    "frappe")
      echo "--color=bg:#414559,fg:#c6d0f5,hl:#e78284 --color=fg+:#c6d0f5,bg+:#626880,hl+:#e78284 --color=info:#8caaee,prompt:#ef9f76,spinner:#e5c890 --color=header:#ca9ee6,marker:#99d1db --color=border:#737994"
      ;;
    "macchiato")
      echo "--color=bg:#24273a,fg:#cad3f5,hl:#ed8796 --color=fg+:#cad3f5,bg+:#5b6078,hl+:#ed8796 --color=info:#8aadf4,prompt:#f5a97f,spinner:#eed49f --color=header:#c6a0f6,marker:#91d7e3 --color=border:#6e738d"
      ;;
  esac
}

# ===================================================================
# COMMAND FUNCTIONS
# ===================================================================

usage() {
  print -P "%F{yellow}Usage:%f zsh theme.sh <set|get|list> [theme_name]"
  print -P "%F{yellow}Commands:%f"
  print -P "  set <theme>  - Set Catppuccin theme (mocha|latte|frappe|macchiato)"
  print -P "  get          - Get current theme"
  print -P "  list         - List available themes"
  exit 1
}

cmd_list() {
  print_color yellow "Available Catppuccin themes:"
  for theme in "${VALID_THEMES[@]}"; do
    if [[ "$theme" == "$(get_current_theme)" ]]; then
      print_color green "  * $theme (current)"
    else
      print_color cyan "    $theme"
    fi
  done
}

cmd_get() {
  local current_theme=$(get_current_theme)
  print_color green "Current theme: $current_theme"
}

cmd_set() {
  local new_theme="$1"
  
  if [[ -z "$new_theme" ]]; then
    print_color red "Error: Theme name required"
    usage
  fi
  
  if ! validate_theme "$new_theme"; then
    print_color red "Error: Invalid theme '$new_theme'"
    print_color yellow "Valid themes: ${VALID_THEMES[*]}"
    return 1
  fi
  
  local current_theme=$(get_current_theme)
  if [[ "$new_theme" == "$current_theme" ]]; then
    print_color yellow "Theme '$new_theme' is already active"
    return 0
  fi
  
  print_color yellow "Switching from '$current_theme' to '$new_theme'..."
  
  # Update theme config file
  echo "# Catppuccin Theme Configuration" > "$THEME_CONFIG"
  echo "# Valid options: mocha, latte, frappe, macchiato" >> "$THEME_CONFIG"
  echo "CATPPUCCIN_THEME=\"$new_theme\"" >> "$THEME_CONFIG"
  
  # Update Ghostty config
  if [[ -f "$SRC_DIR/ghostty/config" ]]; then
    sed -i.bak "s/theme = catppuccin-.*/theme = catppuccin-$new_theme.conf/" "$SRC_DIR/ghostty/config"
    print_color green "✓ Updated Ghostty theme"
  fi
  
  # Update Zellij config
  if [[ -f "$SRC_DIR/zellij/config.kdl" ]]; then
    sed -i.bak "s/theme \"catppuccin-.*\"/theme \"catppuccin-$new_theme\"/" "$SRC_DIR/zellij/config.kdl"
    print_color green "✓ Updated Zellij theme"
  fi
  
  # Update btop config
  if [[ -f "$SRC_DIR/btop/btop.conf" ]]; then
    sed -i.bak "s/catppuccin_.*\.theme/catppuccin_$new_theme.theme/" "$SRC_DIR/btop/btop.conf"
    print_color green "✓ Updated btop theme"
  fi
  
  # Update FZF colors in .zshrc
  if [[ -f "$SRC_DIR/.zshrc" ]]; then
    local fzf_colors=$(get_fzf_colors "$new_theme")
    local theme_title="Catppuccin $(echo $new_theme | sed 's/./\U&/')"
    
    # Create a temporary file with the new FZF configuration
    local temp_file=$(mktemp)
    local in_fzf_section=false
    local line_count=0
    
    while IFS= read -r line; do
      line_count=$((line_count + 1))
      if [[ "$line" =~ "# Catppuccin .* colors for fzf" ]]; then
        echo "# $theme_title colors for fzf" >> "$temp_file"
        in_fzf_section=true
      elif [[ "$in_fzf_section" == true ]] && [[ "$line" =~ "export FZF_DEFAULT_OPTS=" ]]; then
        echo "export FZF_DEFAULT_OPTS=\"\\
  $fzf_colors \\
\"" >> "$temp_file"
        # Skip the rest of the FZF configuration
        while IFS= read -r line && [[ "$line" =~ "^  --color=|^\"$" ]]; do
          line_count=$((line_count + 1))
        done
        echo "$line" >> "$temp_file"
        in_fzf_section=false
      else
        echo "$line" >> "$temp_file"
      fi
    done < "$SRC_DIR/.zshrc"
    
    mv "$temp_file" "$SRC_DIR/.zshrc"
    print_color green "✓ Updated FZF colors"
  fi
  
  # Clean up backup files
  find "$SRC_DIR" -name "*.bak" -delete 2>/dev/null || true
  
  print_color green "Theme successfully changed to '$new_theme'!"
  print_color cyan "Restart your terminal applications to see the changes."
}

# ===================================================================
# MAIN SCRIPT LOGIC
# ===================================================================

if [[ $# -lt 1 ]]; then
  usage
fi

subcommand="$1"
shift

case "$subcommand" in
  set)
    cmd_set "$1" || exit 1
    ;;
  get)
    cmd_get || exit 1
    ;;
  list)
    cmd_list || exit 1
    ;;
  *)
    usage
    ;;
esac
