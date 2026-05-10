#!/bin/bash

set -e

DOTFILES_REPO="https://github.com/JimmyTranDev/dotfiles.git"
DOTFILES_DIR="$HOME/Programming/JimmyTranDev/dotfiles"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${CYAN}ℹ️  $1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
error() { echo -e "${RED}❌ $1${NC}"; }

install_homebrew() {
	if command -v brew >/dev/null 2>&1; then
		success "Homebrew already installed"
		return
	fi
	info "Installing Homebrew..."
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
	if [[ "$(uname -m)" == "arm64" ]]; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	else
		eval "$(/usr/local/bin/brew shellenv)"
	fi
	success "Homebrew installed"
}

install_git() {
	if command -v git >/dev/null 2>&1; then
		return
	fi
	if [[ "$(uname)" == "Darwin" ]]; then
		info "Installing git via Xcode Command Line Tools..."
		xcode-select --install 2>/dev/null || true
	elif [[ -f /etc/arch-release ]]; then
		sudo pacman -S --needed --noconfirm git
	fi
}

clone_dotfiles() {
	if [[ -d "$DOTFILES_DIR" ]]; then
		success "Dotfiles already cloned"
		return
	fi
	info "Cloning dotfiles..."
	mkdir -p "$(dirname "$DOTFILES_DIR")"
	git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
	success "Dotfiles cloned"
}

setup_bitwarden_secrets() {
	local secrets_file="$HOME/Programming/JimmyTranDev/secrets/env.sh"

	if [[ -f "$secrets_file" ]]; then
		success "Secrets already present"
		return
	fi

	if ! command -v bw >/dev/null 2>&1; then
		if [[ "$(uname)" == "Darwin" ]]; then
			info "Installing Bitwarden CLI..."
			brew install bitwarden-cli
		elif [[ -f /etc/arch-release ]]; then
			info "Installing Bitwarden CLI..."
			sudo pacman -S --needed --noconfirm bitwarden-cli 2>/dev/null || {
				if command -v yay >/dev/null 2>&1; then
					yay -S --needed --noconfirm bitwarden-cli
				else
					warn "Could not install bitwarden-cli. Install it manually and re-run."
					return 1
				fi
			}
		fi
	fi

	info "Downloading secrets from Bitwarden..."
	bash "$DOTFILES_DIR/etc/scripts/src/sync_secrets.sh" download
}

configure_macos_hotkeys() {
	if [[ "$(uname)" != "Darwin" ]]; then
		return
	fi
	info "Configuring macOS hotkeys (disabling Spotlight & emoji for Cmd+Space)..."
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 '{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'
	defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 60 '{ enabled = 0; value = { parameters = (32, 49, 1048576); type = standard; }; }'
	/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
	success "macOS hotkeys configured (Cmd+Space free for Raycast)"
}

start_macos_services() {
	if [[ "$(uname)" != "Darwin" ]]; then
		return
	fi
	if command -v yabai >/dev/null 2>&1; then
		info "Starting yabai service..."
		yabai --start-service
		success "yabai service started"
	else
		warn "yabai not found, skipping service start"
	fi
	if command -v skhd >/dev/null 2>&1; then
		info "Starting skhd service..."
		skhd --start-service
		success "skhd service started"
	else
		warn "skhd not found, skipping service start"
	fi
}

main() {
	echo ""
	echo "================================================"
	echo "  JimmyTranDev Dotfiles Bootstrap"
	echo "================================================"
	echo ""

	install_git

	if [[ "$(uname)" == "Darwin" ]]; then
		install_homebrew
	fi

	clone_dotfiles
	setup_bitwarden_secrets

	configure_macos_hotkeys

	info "Running dotfiles install script..."
	bash "$DOTFILES_DIR/etc/scripts/src/install/install.sh"

	start_macos_services

	echo ""
	success "Bootstrap complete! Restart your terminal or run: source ~/.zshrc"
}

main "$@"
