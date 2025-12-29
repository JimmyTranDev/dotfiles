#!/bin/bash

# Link management script for dotfiles
# Creates symlinks for dotfiles configuration

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$HOME/Programming/dotfiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emoji for better UX
EMOJI_SUCCESS="✓"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_INFO="ℹ️"
EMOJI_ROCKET="🚀"
EMOJI_LINK="🔗"
EMOJI_TRASH="🗑"
EMOJI_EYE="👁"

# Function to log messages
log_info() {
    echo -e "${CYAN}${EMOJI_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${EMOJI_SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${EMOJI_ERROR} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${EMOJI_WARNING} $1${NC}"
}

log_header() {
    echo -e "${BLUE}${EMOJI_ROCKET} $1${NC}"
}

# Get platform-specific link mappings
get_macos_links() {
    local links=(
        "$HOME/Programming/nvim $HOME/.config/nvim"
        "$HOME/Programming/dotfiles/src/yazi $HOME/.config/yazi"
        "$HOME/Programming/dotfiles/src/zellij $HOME/.config/zellij"
        "$HOME/Programming/dotfiles/src/lazygit $HOME/.config/lazygit"
        "$HOME/Programming/dotfiles/src/.zshrc $HOME/.zshrc"
        "$HOME/Programming/dotfiles/src/.ideavimrc $HOME/.ideavimrc"
        "$HOME/Programming/dotfiles/src/.gitignore_global $HOME/.gitignore_global"
        "$HOME/Programming/dotfiles/src/Brewfile $HOME/Brewfile"
        "$HOME/Programming/secrets/.gitconfig $HOME/.gitconfig"
        "$HOME/Programming/secrets/.m2 $HOME/.m2"
        "$HOME/Programming/secrets/.npmrc $HOME/.npmrc"
        "$HOME/Programming/dotfiles/src/skhd $HOME/.config/skhd"
        "$HOME/Programming/dotfiles/src/yabai $HOME/.config/yabai"
        "$HOME/Programming/dotfiles/src/btop $HOME/.config/btop"
        "$HOME/Programming/dotfiles/src/starship.toml $HOME/.config/starship.toml"
        "$HOME/Programming/dotfiles/src/ghostty $HOME/.config/ghostty"
        "$HOME/Programming/dotfiles/src/opencode $HOME/.config/opencode"
    )
    printf '%s\n' "${links[@]}"
}

get_linux_links() {
    local links=(
        "$HOME/Programming/dotfiles/src/nvim $HOME/.config/nvim"
        "$HOME/Programming/dotfiles/src/yazi $HOME/.config/yazi"
        "$HOME/Programming/dotfiles/src/zellij $HOME/.config/zellij"
        "$HOME/Programming/dotfiles/src/lazygit $HOME/.config/lazygit"
        "$HOME/Programming/dotfiles/src/.zshrc $HOME/.zshrc"
        "$HOME/Programming/dotfiles/src/.ideavimrc $HOME/.ideavimrc"
        "$HOME/Programming/dotfiles/src/.gitignore_global $HOME/.gitignore_global"
        "$HOME/Programming/secrets/.gitconfig $HOME/.gitconfig"
        "$HOME/Programming/secrets/.m2 $HOME/.m2"
        "$HOME/Programming/secrets/.npmrc $HOME/.npmrc"
        "$HOME/Programming/dotfiles/src/btop $HOME/.config/btop"
        "$HOME/Programming/dotfiles/src/starship.toml $HOME/.config/starship.toml"
        "$HOME/Programming/dotfiles/src/opencode $HOME/.config/opencode"
    )
    printf '%s\n' "${links[@]}"
}

# Get links based on current platform
get_platform_links() {
    if [ "$(uname)" == "Darwin" ]; then
        get_macos_links
    elif [ "$(uname)" == "Linux" ]; then
        get_linux_links
    else
        log_error "Unsupported platform: $(uname)"
        exit 1
    fi
}

# Create symlinks
create_links() {
    log_header "Creating dotfiles symlinks..."
    
    # Ensure .config directory exists
    mkdir -p "$HOME/.config"
    
    local success_count=0
    local total_count=0
    
    while IFS= read -r entry; do
        [ -z "$entry" ] && continue
        
        local src=$(echo "$entry" | awk '{print $1}')
        local dest=$(echo "$entry" | awk '{print $2}')
        
        total_count=$((total_count + 1))
        
        # Check if source exists
        if [ ! -e "$src" ]; then
            log_warning "Skipping $(basename "$dest") (source not found: $src)"
            continue
        fi
        
        # Create destination directory if needed
        local dest_dir=$(dirname "$dest")
        mkdir -p "$dest_dir"
        
        # Remove existing destination
        if [ -e "$dest" ] || [ -L "$dest" ]; then
            rm -rf "$dest"
        fi
        
        # Create symlink
        if ln -s "$src" "$dest"; then
            log_success "Created link: $(basename "$dest")"
            success_count=$((success_count + 1))
        else
            log_error "Failed to create link: $src -> $dest"
        fi
    done <<< "$(get_platform_links)"
    
    echo
    log_info "${EMOJI_LINK} Linking Summary:"
    log_info "  • Successfully linked: $success_count files"
    log_info "  • Failed links: $((total_count - success_count)) files"
    log_info "  • Total files processed: $total_count"
    
    if [ $success_count -lt $total_count ]; then
        log_warning "Some links failed - check the output above for details"
    fi
}

# Main function
main() {
    create_links
}

# Run main function with all arguments
main "$@"