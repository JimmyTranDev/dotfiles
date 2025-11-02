#!/bin/bash

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

if [ "$(uname)" == "Darwin" ]; then
  echo "Detected macOS. Running macOS setup..."
  # Symlink dotfiles
  mkdir -p "$HOME/.config"
  links=(
    "$HOME/Programming/nvim $HOME/.config/nvim"
    "$HOME/Programming/dotfiles/src/yazi $HOME/.config/yazi"
    "$HOME/Programming/dotfiles/src/zellij $HOME/.config/zellij"
    "$HOME/Programming/dotfiles/src/lazygit $HOME/.config/lazygit"
    "$HOME/Programming/dotfiles/src/.zshrc $HOME/.zshrc"
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
    "$HOME/Programming/dotfiles/src/claude $HOME/.config/claude"
  )
  for entry in "${links[@]}"; do
    src=$(echo "$entry" | awk '{print $1}')
    dest=$(echo "$entry" | awk '{print $2}')
    rm -rf "$dest"
    ln -s "$src" "$dest"
  done
  echo " Done linking dotfiles."
  # Install Homebrew packages
  if command -v brew >/dev/null 2>&1; then
    brew bundle --file="$HOME/Brewfile" check ||
      brew bundle --file="$HOME/Brewfile" install ||
      brew bundle --file="$HOME/Brewfile" cleanup --force
  else
    echo "Homebrew not found. Please install Homebrew first."
  fi
elif [ "$(uname)" == "Linux" ]; then
  echo "Detected Linux. Running Linux/WSL setup..."
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
  echo " Updating system and installing packages..."
  sudo pacman -Syu --noconfirm
  for pkg in "${packages[@]}"; do
    sudo pacman -S --needed --noconfirm "$pkg"
  done
  aurs=(fnm)
  echo " Updating AUR and installing AUR packages..."
  paru -Syu --noconfirm
  for aur in "${aurs[@]}"; do
    paru -S --needed --noconfirm "$aur"
  done
  # Symlink dotfiles
  mkdir -p "$HOME/.config"
  links=(
    "$HOME/Programming/dotfiles/src/nvim $HOME/.config/nvim"
    "$HOME/Programming/dotfiles/src/yazi $HOME/.config/yazi"
    "$HOME/Programming/dotfiles/src/zellij $HOME/.config/zellij"
    "$HOME/Programming/dotfiles/src/lazygit $HOME/.config/lazygit"
    "$HOME/Programming/dotfiles/src/.zshrc $HOME/.zshrc"
    "$HOME/Programming/secrets/.gitconfig $HOME/.gitconfig"
    "$HOME/Programming/secrets/.m2 $HOME/.m2"
    "$HOME/Programming/secrets/.npmrc $HOME/.npmrc"
    "$HOME/Programming/dotfiles/src/btop $HOME/.config/btop"
    "$HOME/Programming/dotfiles/src/starship.toml $HOME/.config/starship.toml"
    "$HOME/Programming/dotfiles/src/opencode $HOME/.config/opencode"
    "$HOME/Programming/dotfiles/src/claude $HOME/.config/claude"
  )
  for entry in "${links[@]}"; do
    src=$(echo "$entry" | awk '{print $1}')
    dest=$(echo "$entry" | awk '{print $2}')
    rm -rf "$dest"
    ln -s "$src" "$dest"
  done
  echo "Done linking dotfiles."
fi

echo "Setup completed successfully!"
