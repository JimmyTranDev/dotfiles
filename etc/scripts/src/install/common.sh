#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/etc/scripts"

source "$SCRIPTS_DIR/utils/utility.sh"
source "$SCRIPTS_DIR/utils/logging.sh"

main() {
	log_header "Running common setup..."

	find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

	if [ ! -d "$HOME/.oh-my-zsh" ]; then
		log_info "Installing Oh My Zsh..."
		sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
	else
		log_info "Oh My Zsh already installed"
	fi

	if [ ! -d "$DOTFILES_ROOT/src/nvim" ]; then
		log_warning "Nvim config not found at $DOTFILES_ROOT/src/nvim — it should be part of dotfiles"
	else
		log_info "Nvim config exists in dotfiles"
	fi

	log_info "Syncing symbolic links..."
	"$SCRIPTS_DIR/src/install/sync_links.sh"

	if command -v ya >/dev/null 2>&1; then
		read -rp "Update yazi packages? [y/N] " answer </dev/tty
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			log_info "Installing yazi packages..."
			ya pkg install || log_warning "ya pkg install failed (may need network)"
		else
			log_info "Skipping yazi packages"
		fi
	fi

	if command -v pipx >/dev/null 2>&1; then
		read -rp "Install pipx packages? [y/N] " answer </dev/tty
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			log_info "Installing pipx packages..."
			pipx install diff-cover || log_warning "diff-cover install failed"
		else
			log_info "Skipping pipx packages"
		fi
	else
		log_warning "pipx not found, skipping pipx packages"
	fi

	if command -v pnpm >/dev/null 2>&1; then
		read -rp "Install global pnpm packages? [y/N] " answer </dev/tty
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			log_info "Installing global pnpm packages..."
			pnpm add -g @doist/todoist-cli
			pnpm add -g @_davideast/stitch-mcp
		else
			log_info "Skipping global pnpm packages"
		fi
	else
		log_warning "pnpm not found, skipping global pnpm packages"
	fi

	log_success "Common setup completed"
}

main "$@"
