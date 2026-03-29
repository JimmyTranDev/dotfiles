#!/bin/bash

# Common installation steps shared across all platforms

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../" && pwd)"
SCRIPTS_DIR="$DOTFILES_DIR/etc/scripts"

source "$SCRIPTS_DIR/common/utility.sh"

echo "Running common setup..."

# Make scripts executable
find "$SCRIPTS_DIR" -type f -name "*.sh" -exec chmod +x {} \;

# Install Oh My Zsh if not already installed
if [ ! -d "$HOME/.oh-my-zsh" ]; then
	echo "Installing Oh My Zsh..."
	sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
	echo "Oh My Zsh already installed"
fi

# Clone nvim config if it doesn't exist
if [ ! -d "$HOME/Programming/JimmyTranDev/nvim" ]; then
	echo "Cloning nvim configuration..."
	mkdir -p "$HOME/Programming/JimmyTranDev"
	if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
		git clone git@github.com:JimmyTranDev/nvim-config.git "$HOME/Programming/JimmyTranDev/nvim"
	else
		git clone https://github.com/JimmyTranDev/nvim-config.git "$HOME/Programming/JimmyTranDev/nvim"
	fi
else
	echo "Nvim config already exists"
fi

echo "Syncing symbolic links..."
"$SCRIPTS_DIR/sync_links.sh"

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

	echo "Generating config files from templates..."
	generate_from_template "$TEMPLATES_DIR/.gitconfig" "$HOME/.gitconfig"
	generate_from_template "$TEMPLATES_DIR/.m2/settings.xml" "$HOME/.m2/settings.xml"
	generate_from_template "$TEMPLATES_DIR/.npmrc" "$HOME/.npmrc"
	echo "Config files generated"
fi

if command -v npm >/dev/null 2>&1; then
	echo "Installing global npm packages..."
	npm install -g @doist/todoist-cli
	npm install -g @_davideast/stitch-mcp
else
	echo "npm not found, skipping global npm packages"
fi

echo "Common setup completed"
