#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"

show_help() {
	cat <<'EOF'
Usage: bootstrap.sh [options]

Set up a full development environment on Termux (Android).

OPTIONS:
  --minimal     Install only core tools (git, zsh, nvim, starship)
  --skip-ssh    Skip SSH key generation
  -h, --help    Show this help message
EOF
}

install_packages() {
	local minimal="$1"

	log_header "Installing core packages..."
	pkg update -y
	pkg upgrade -y

	local core_packages=(
		git
		zsh
		openssh
		curl
		wget
		ripgrep
		fd
		fzf
		neovim
		starship
		python
		jq
	)

	pkg install -y "${core_packages[@]}"

	if [[ "$minimal" != "true" ]]; then
		log_header "Installing additional packages..."
		local extra_packages=(
			nodejs-lts
			yazi
			bat
			zoxide
			lazygit
			delta
		)
		pkg install -y "${extra_packages[@]}"

		if command -v npm &>/dev/null; then
			hash -r
			npm install -g pnpm
		fi
	fi
}

setup_storage() {
	log_header "Setting up storage access..."
	if [[ ! -d "$HOME/storage" ]]; then
		log_info "You may see a storage permission dialog..."
		termux-setup-storage
		log_success "Storage access configured"
	else
		log_info "Storage already configured"
	fi
}

setup_shell() {
	log_header "Setting up zsh..."
	if [[ "$SHELL" != *zsh ]]; then
		chsh -s zsh
	fi

	if [[ ! -f "$HOME/.zshrc" ]]; then
		cat >"$HOME/.zshrc" <<'ZSHRC'
export TERMUX=true
export EDITOR=nvim
export VISUAL=nvim

eval "$(starship init zsh)"
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

alias ll="ls -la"
alias vim="nvim"
alias lg="lazygit"
ZSHRC
		log_success "Created .zshrc"
	else
		log_info ".zshrc already exists"
	fi
}

setup_ssh() {
	local skip_ssh="$1"

	if [[ "$skip_ssh" == "true" ]]; then
		log_info "Skipping SSH setup"
		return
	fi

	log_header "Setting up SSH..."

	if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
		mkdir -p "$HOME/.ssh"
		chmod 700 "$HOME/.ssh"
		ssh-keygen -t ed25519 -C "termux@android" -f "$HOME/.ssh/id_ed25519" -N ""
		log_success "SSH key generated"
		log_info "Public key:"
		cat "$HOME/.ssh/id_ed25519.pub"
		log_info "Add this key to your GitHub account: https://github.com/settings/keys"
	else
		log_info "SSH key already exists"
	fi
}

clone_dotfiles() {
	local dotfiles_dir="$HOME/Programming/dotfiles"

	log_header "Setting up dotfiles..."

	if [[ -d "$dotfiles_dir" ]]; then
		log_info "Dotfiles already cloned at $dotfiles_dir"
		return
	fi

	mkdir -p "$HOME/Programming"
	git clone git@github.com:JimmyTranDev/dotfiles.git "$dotfiles_dir" || {
		log_warning "SSH clone failed, trying HTTPS..."
		git clone https://github.com/JimmyTranDev/dotfiles.git "$dotfiles_dir"
	}

	log_success "Dotfiles cloned to $dotfiles_dir"
}

symlink_configs() {
	local dotfiles_dir="$HOME/Programming/dotfiles"

	if [[ ! -d "$dotfiles_dir" ]]; then
		log_warning "Dotfiles not found, skipping symlinks"
		return
	fi

	log_header "Symlinking configs..."

	local links=(
		"$dotfiles_dir/src/nvim:$HOME/.config/nvim"
		"$dotfiles_dir/src/starship.toml:$HOME/.config/starship.toml"
		"$dotfiles_dir/src/git/.gitconfig:$HOME/.gitconfig"
		"$dotfiles_dir/src/lazygit:$HOME/.config/lazygit"
	)

	for link in "${links[@]}"; do
		local src="${link%%:*}"
		local dst="${link##*:}"

		if [[ ! -e "$src" ]]; then
			log_warning "Source not found: $src"
			continue
		fi

		mkdir -p "$(dirname "$dst")"

		if [[ -L "$dst" ]]; then
			log_info "Already linked: $dst"
		elif [[ -e "$dst" ]]; then
			log_warning "File exists (not a symlink): $dst — skipping"
		else
			ln -s "$src" "$dst"
			log_success "Linked: $dst -> $src"
		fi
	done
}

main() {
	local minimal=false
	local skip_ssh=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--minimal) minimal=true; shift ;;
		--skip-ssh) skip_ssh=true; shift ;;
		-h | --help) show_help; exit 0 ;;
		*) log_error "Unknown option: $1"; show_help; exit 1 ;;
		esac
	done

	log_header "Termux Bootstrap"
	log_info "Starting setup..."

	install_packages "$minimal"
	setup_storage
	setup_shell
	setup_ssh "$skip_ssh"
	clone_dotfiles
	symlink_configs

	log_success "Bootstrap complete!"
	log_info "Restart Termux to use zsh as your default shell."
}

main "$@"
