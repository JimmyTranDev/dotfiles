#!/bin/bash

# Arch Linux package installation

set -e

echo "Running Arch Linux setup..."

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
		btop
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

	echo "Updating system and installing packages..."
	sudo pacman -Syu --noconfirm
	for pkg in "${packages[@]}"; do
		sudo pacman -S --needed --noconfirm "$pkg"
	done
else
	echo "pacman not found. Please ensure you are running Arch Linux."
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
	echo "Installing AUR packages..."
	yay -Syu --noconfirm
	for aur in "${aurs[@]}"; do
		yay -S --needed --noconfirm "$aur"
	done
else
	echo "yay not found. Skipping AUR packages."
	echo '  Install yay: https://github.com/Jguer/yay'
fi

echo "Arch Linux setup completed"
