#!/bin/bash

# Arch Linux package installation

set -e

echo "Running Arch Linux setup..."

packages=(
	# --- Containers & DevOps ---
	docker
	docker-compose

	# --- Version Control & Dev Tools ---
	git
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

	# --- File Management & Utilities ---
	fd
	ripgrep
	lsof
	xclip
	wget
	p7zip
	poppler
	ffmpegthumbnailer
	imagemagick
	jq
	yazi

	# --- Programming Languages & Tools ---
	pnpm
	python
	python-poetry
	luarocks
	clang
	gopls
)

echo "Updating system and installing packages..."
sudo pacman -Syu --noconfirm
for pkg in "${packages[@]}"; do
	sudo pacman -S --needed --noconfirm "$pkg"
done

aurs=(fnm)
echo "Installing AUR packages..."
paru -Syu --noconfirm
for aur in "${aurs[@]}"; do
	paru -S --needed --noconfirm "$aur"
done

echo "Arch Linux setup completed"
