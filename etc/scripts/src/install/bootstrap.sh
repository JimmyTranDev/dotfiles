#!/bin/bash

set -e

DOTFILES_REPO_SSH="git@github.com:JimmyTranDev/dotfiles.git"
DOTFILES_REPO_HTTPS="https://github.com/JimmyTranDev/dotfiles.git"
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
	# Prefer SSH so the clone uses your SSH key. On a brand-new machine the
	# key is not registered with GitHub yet (it arrives later via Bitwarden),
	# so fall back to HTTPS; main() switches the remote to SSH afterward.
	if git clone "$DOTFILES_REPO_SSH" "$DOTFILES_DIR" 2>/dev/null; then
		success "Dotfiles cloned via SSH"
	else
		warn "SSH clone failed, falling back to HTTPS..."
		git clone "$DOTFILES_REPO_HTTPS" "$DOTFILES_DIR"
		success "Dotfiles cloned via HTTPS"
	fi
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
			if command -v yay >/dev/null 2>&1; then
				yay -S --needed --noconfirm bitwarden-cli
			elif command -v paru >/dev/null 2>&1; then
				paru -S --needed --noconfirm bitwarden-cli
			else
				warn "Could not install bitwarden-cli. Install yay or paru first, then re-run."
				return 1
			fi
		fi
	fi

	info "Downloading secrets from Bitwarden..."
	bash "$DOTFILES_DIR/etc/scripts/src/sync_secrets.sh" download
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
	elif [[ -f /etc/arch-release ]]; then
		info "Installing base dependencies for Arch Linux..."
		sudo pacman -S --needed --noconfirm base-devel curl unzip
		success "Arch base dependencies installed"
	fi

	clone_dotfiles
	setup_bitwarden_secrets

	info "Switching dotfiles remote to SSH..."
	git -C "$DOTFILES_DIR" remote set-url origin git@github.com:JimmyTranDev/dotfiles.git
	success "Dotfiles remote switched to SSH"

	info "Running dotfiles install script..."
	bash "$DOTFILES_DIR/etc/scripts/src/install/install.sh"

	echo ""
	success "Bootstrap complete! Restart your terminal or run: source ~/.zshrc"
}

main "$@"
