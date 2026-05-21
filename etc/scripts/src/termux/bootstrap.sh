#!/bin/bash
set -e

DOTFILES_REPO="https://github.com/JimmyTranDev/dotfiles.git"
DOTFILES_DIR="$HOME/Programming/JimmyTranDev/dotfiles"

# When piped from curl, BASH_SOURCE[0] won't resolve to a real path.
# The fallback logging functions below handle this gracefully.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
LOGGING_SH="${SCRIPT_DIR:+$SCRIPT_DIR/../../utils/logging.sh}"
if [[ -n "$LOGGING_SH" && -f "$LOGGING_SH" ]]; then
	source "$LOGGING_SH"
else
	log_header() { echo "==> $1"; }
	log_info() { echo "[INFO] $1"; }
	log_success() { echo "[OK] $1"; }
	log_warning() { echo "[WARN] $1"; }
	log_error() { echo "[ERROR] $1" >&2; }
fi

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
			git-delta
		)
		pkg install -y "${extra_packages[@]}"
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

	if [[ "$SHELL" != *"zsh"* ]]; then
		chsh -s zsh
		log_success "Default shell set to zsh"
	else
		log_info "zsh is already the default shell"
	fi

	if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
		log_info "Installing Oh My Zsh..."
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
		log_success "Oh My Zsh installed"
	else
		log_info "Oh My Zsh already installed"
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
	log_header "Setting up dotfiles..."

	# Migrate old path if it exists
	local old_path="$HOME/Programming/dotfiles"
	if [[ -d "$old_path" && ! -d "$DOTFILES_DIR" ]]; then
		log_info "Migrating dotfiles from $old_path to $DOTFILES_DIR..."
		mkdir -p "$(dirname "$DOTFILES_DIR")"
		mv "$old_path" "$DOTFILES_DIR"
		log_success "Dotfiles migrated to $DOTFILES_DIR"
		return
	fi

	if [[ -d "$DOTFILES_DIR" ]]; then
		log_info "Dotfiles already cloned at $DOTFILES_DIR"
		return
	fi

	mkdir -p "$(dirname "$DOTFILES_DIR")"
	git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
	log_success "Dotfiles cloned to $DOTFILES_DIR"
}

switch_remote_to_ssh() {
	if [[ ! -d "$DOTFILES_DIR" ]]; then
		return
	fi

	log_info "Switching dotfiles remote to SSH..."
	git -C "$DOTFILES_DIR" remote set-url origin git@github.com:JimmyTranDev/dotfiles.git
	log_success "Dotfiles remote switched to SSH"
}

setup_bitwarden_secrets() {
	local secrets_file="$HOME/Programming/JimmyTranDev/secrets/env.sh"

	if [[ -f "$secrets_file" ]]; then
		log_success "Secrets already present"
		return
	fi

	if ! command -v bw &>/dev/null; then
		if command -v npm &>/dev/null; then
			log_info "Installing Bitwarden CLI via npm..."
			npm install -g @bitwarden/cli || {
				log_warning "Bitwarden CLI install failed, skipping secrets"
				return
			}
			hash -r
		else
			log_warning "npm not available, skipping Bitwarden CLI install"
			return
		fi
	fi

	if [[ -f "$DOTFILES_DIR/etc/scripts/src/sync_secrets.sh" ]]; then
		log_info "Downloading secrets from Bitwarden..."
		bash "$DOTFILES_DIR/etc/scripts/src/sync_secrets.sh" download || {
			log_warning "Secrets download failed — you can re-run sync_secrets.sh later"
		}
	else
		log_warning "sync_secrets.sh not found, skipping secrets download"
	fi
}

symlink_configs() {
	if [[ ! -d "$DOTFILES_DIR" ]]; then
		log_warning "Dotfiles not found, skipping symlinks"
		return
	fi

	# Ensure TERMUX_VERSION is exported so sync_links.sh detects Termux
	export TERMUX_VERSION="${TERMUX_VERSION:-}"

	log_header "Syncing symbolic links..."
	bash "$DOTFILES_DIR/etc/scripts/src/install/sync_links.sh"
}

setup_tools() {
	log_header "Setting up additional tools..."

	if command -v npm &>/dev/null; then
		log_info "Installing global npm packages..."
		npm install -g pnpm @doist/todoist-cli || {
			log_warning "Some npm global installs failed"
		}
		hash -r
	else
		log_warning "npm not found, skipping global npm packages"
	fi

	install_opencode

	if command -v ya &>/dev/null; then
		log_info "Installing yazi packages..."
		ya pkg install || log_warning "ya pkg install failed (may need network)"
	fi
}

install_opencode() {
	if command -v opencode &>/dev/null; then
		log_info "OpenCode already installed"
		return
	fi

	local script="$DOTFILES_DIR/etc/scripts/src/termux/install-opencode.sh"
	if [[ -f "$script" ]]; then
		bash "$script"
	else
		log_warning "install-opencode.sh not found, skipping OpenCode install"
	fi
}

set_script_permissions() {
	if [[ -d "$DOTFILES_DIR/etc/scripts" ]]; then
		find "$DOTFILES_DIR/etc/scripts" -type f -name "*.sh" -exec chmod +x {} \;
		log_success "Script permissions set"
	fi
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

	echo ""
	echo "================================================"
	echo "  JimmyTranDev Dotfiles Bootstrap (Termux)"
	echo "================================================"
	echo ""

	install_packages "$minimal"
	setup_storage
	setup_ssh "$skip_ssh"
	clone_dotfiles
	switch_remote_to_ssh
	set_script_permissions
	setup_bitwarden_secrets
	setup_shell
	symlink_configs

	if [[ "$minimal" != "true" ]]; then
		setup_tools
	fi

	log_success "Bootstrap complete!"
	log_info "Restart Termux to use zsh as your default shell."
}

main "$@"
