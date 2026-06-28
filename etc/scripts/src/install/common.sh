#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/etc/scripts"

source "$SCRIPTS_DIR/utils/utility.sh"
source "$SCRIPTS_DIR/utils/logging.sh"

main() {
	log_header "Running common setup..."

	find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

	if [ ! -d "$DOTFILES_DIR/src/nvim" ]; then
		log_warning "Nvim config not found at $DOTFILES_DIR/src/nvim — it should be part of dotfiles"
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
			pnpm add -g eas-cli
		else
			log_info "Skipping global pnpm packages"
		fi
	else
		log_warning "pnpm not found, skipping global pnpm packages"
	fi

	if command -v gh >/dev/null 2>&1; then
		read -rp "Install gh CLI extensions (gh-dash, gh-enhance)? [y/N] " answer </dev/tty
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			log_info "Installing gh extensions..."
			gh extension install dlvhdr/gh-dash || log_warning "gh-dash install failed (may already be installed)"
			gh extension install dlvhdr/gh-enhance ||
				gh extension install dlvhdr-insiders/gh-enhance ||
				log_warning "gh-enhance install failed (may already be installed)"
		else
			log_info "Skipping gh extensions"
		fi
	else
		log_warning "gh not found, skipping gh extensions"
	fi

	if [[ ! -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
		log_info "Installing SDKMAN..."
		bash -c "$(curl -fsSL https://get.sdkman.io)" || log_warning "SDKMAN installation failed"
		if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
			log_success "SDKMAN installed"
		fi
	else
		log_info "SDKMAN already installed"
	fi

	if [[ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]]; then
		source "$HOME/.sdkman/bin/sdkman-init.sh"
		if ! sdk list java | grep -q "21\.[^ ]* .* installed"; then
			log_info "Installing Java 21 via SDKMAN..."
			sdk install java 21-tem || sdk install java 21-open || log_warning "Java 21 installation failed"
			log_success "Java 21 installed"
		else
			log_info "Java 21 already installed"
		fi
		log_info "Setting Java 21 as default..."
		sdk default java 21-tem 2>/dev/null || sdk default java 21-open 2>/dev/null || log_warning "Could not set Java 21 as default"
	fi

	read -rp "Install storecode (AI coding tool)? [y/N] " answer </dev/tty
	if [[ "$answer" =~ ^[Yy]$ ]]; then
		"$SCRIPTS_DIR/src/install/storecode.sh"
	else
		log_info "Skipping storecode"
	fi

	log_success "Common setup completed"
}

main "$@"
