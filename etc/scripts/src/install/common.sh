#!/bin/bash

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
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

	if [ ! -d "$HOME/Programming/JimmyTranDev/nvim" ]; then
		log_info "Cloning nvim configuration..."
		mkdir -p "$HOME/Programming/JimmyTranDev"
		if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
			git clone git@github.com:JimmyTranDev/nvim-config.git "$HOME/Programming/JimmyTranDev/nvim"
		else
			git clone https://github.com/JimmyTranDev/nvim-config.git "$HOME/Programming/JimmyTranDev/nvim"
		fi
	else
		log_info "Nvim config already exists"
	fi

	log_info "Syncing symbolic links..."
	"$SCRIPTS_DIR/src/sync_links.sh"

	if command -v ya >/dev/null 2>&1; then
		log_info "Installing yazi packages..."
		ya pkg install || log_warning "ya pkg install failed (may need network)"
	fi

	SECRETS_ENV="$HOME/Programming/JimmyTranDev/secrets/env.sh"
	if [[ -f "$SECRETS_ENV" ]]; then
		source "$SECRETS_ENV"

		TEMPLATES_DIR="$DOTFILES_DIR/etc/templates"

		generate_from_template() {
			local template="$1"
			local output="$2"
			local output_dir
			output_dir="$(dirname "$output")"

			if [ -L "$output_dir" ]; then
				rm "$output_dir"
			fi
			if [ -L "$output" ]; then
				rm "$output"
			fi

			mkdir -p "$output_dir"

			sed \
				-e "s|{{HOME}}|$HOME|g" \
				-e "s|{{PRI_EMAIL}}|${PRI_EMAIL}|g" \
				-e "s|{{PRI_GITHUB_USERNAME}}|${PRI_GITHUB_USERNAME}|g" \
				-e "s|{{PRI_GITHUB_TOKEN}}|${PRI_GITHUB_TOKEN}|g" \
				-e "s|{{ORG_GITHUB_NAME}}|${ORG_GITHUB_NAME}|g" \
				"$template" >"$output"
		}

		log_info "Generating config files from templates..."
		generate_from_template "$TEMPLATES_DIR/.gitconfig" "$HOME/.gitconfig"
		generate_from_template "$TEMPLATES_DIR/.m2/settings.xml" "$HOME/.m2/settings.xml"
		generate_from_template "$TEMPLATES_DIR/.npmrc" "$HOME/.npmrc"
		log_success "Config files generated"
	fi

	if command -v npm >/dev/null 2>&1; then
		log_info "Installing global npm packages..."
		npm install -g @doist/todoist-cli
		npm install -g @_davideast/stitch-mcp
	else
		log_warning "npm not found, skipping global npm packages"
	fi

	log_success "Common setup completed"
}

main "$@"
