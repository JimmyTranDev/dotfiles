#!/bin/bash

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$(uname)" == "Darwin" ]; then
  echo "🚀 Detected macOS. Running macOS setup..."

  # Create symlinks using dedicated link script
  "$SCRIPT_DIR/link.sh" create

  if command -v brew >/dev/null 2>&1; then
    echo "📦 Installing Homebrew packages..."
    brew bundle --file="$HOME/Brewfile" check ||
      brew bundle --file="$HOME/Brewfile" install ||
      brew bundle --file="$HOME/Brewfile" cleanup --force
  else
    echo "⚠️ Homebrew not found. Please install Homebrew first."
  fi

elif [ "$(uname)" == "Linux" ]; then
  echo "🚀 Detected Linux. Running Linux/WSL setup..."

  # Install packages (Arch/WSL example)
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

  echo "📦 Updating system and installing packages..."
  sudo pacman -Syu --noconfirm
  for pkg in "${packages[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg"
  done

  aurs=(fnm)
  echo "📦 Updating AUR and installing AUR packages..."
  paru -Syu --noconfirm
  for aur in "${aurs[@]}"; do
    paru -S --needed --noconfirm "$aur"
  done

  # Create symlinks using dedicated link script
  "$SCRIPT_DIR/link.sh" create

fi

echo "✅ Setup completed successfully!"
