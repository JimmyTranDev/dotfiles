#!/bin/bash

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALL_DIR/../../utils/logging.sh"

main() {
	log_header "Running Arch Linux setup..."

	if command -v pacman >/dev/null 2>&1; then
		packages=(
			# --- Containers & DevOps ---
			docker
			docker-compose

			# --- Version Control & Dev Tools ---
			git
			git-delta
			github-cli
			lazygit
			starship

			# --- Editors ---
			neovim
			vim

			# --- Shell & Terminal ---
			zsh
			zellij
			fzf
			zoxide
			shfmt
			tree

			# --- Desktop Environment ---
			hyprland
			hyprlock
			hypridle
			hyprsunset

			# --- File Management & Utilities ---
			fd
			ripgrep
			bat
			chafa
			lsof
			xclip
			wget
			curl
			p7zip
			poppler
			ffmpegthumbnailer
			imagemagick
			jq
			ntfs-3g
			unarchiver
			yazi

			# --- Programming Languages & Tools ---
			pnpm
			yarn
			maven
			python
			python-poetry
			python-pipx
			ruby
			go
			rust
			luarocks
			clang
			gopls
		)

		log_info "Updating system and installing packages..."
		sudo pacman -Syu --noconfirm
		for pkg in "${packages[@]}"; do
			sudo pacman -S --needed --noconfirm "$pkg"
		done
	else
		log_error "pacman not found. Please ensure you are running Arch Linux."
		exit 1
	fi

	if command -v yay >/dev/null 2>&1; then
		aurs=(
			android-studio
			fnm
			luacheck
			stylua
			trufflehog
		)
		log_info "Installing AUR packages..."
		yay -Syu --noconfirm
		for aur in "${aurs[@]}"; do
			yay -S --needed --noconfirm "$aur"
		done
	else
		log_warning "yay not found. Skipping AUR packages."
		log_info "Install yay: https://github.com/Jguer/yay"
	fi

	if command -v go >/dev/null 2>&1; then
		log_info "Installing diffnav via go..."
		go install github.com/dlvhdr/diffnav@latest || log_warning "diffnav install failed"
	else
		log_warning "go not found, skipping diffnav"
	fi

	log_success "Arch Linux setup completed"
}

main "$@"
