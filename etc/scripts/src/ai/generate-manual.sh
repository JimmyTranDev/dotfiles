#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

DOTFILES_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
DEFAULT_OUTPUT="$DOTFILES_DIR/etc/docs/manual.md"

show_help() {
	log_info "Usage: generate-manual.sh [OPTIONS]"
	log_info ""
	log_info "Generate a reference manual from dotfiles keymaps, aliases, and configs."
	log_info ""
	log_info "Options:"
	log_info "  --output <path>    Output file path (default: etc/docs/manual.md)"
	log_info "  --help             Show this help message"
}

parse_neovim_keymaps() {
	local keymaps_file="$DOTFILES_DIR/src/nvim/lua/core/keymaps.lua"

	if [[ ! -f "$keymaps_file" ]]; then
		log_warning "keymaps.lua not found at $keymaps_file"
		return
	fi

	# Parse single map() calls: map('mode', '<key>', ..., { desc = 'description' })
	grep -E "^map\(" "$keymaps_file" | while IFS= read -r line; do
		local mode key desc
		mode=$(echo "$line" | sed -n "s/^map('\([^']*\)'.*/\1/p")
		key=$(echo "$line" | sed -n "s/^map('[^']*', '\([^']*\)'.*/\1/p")
		desc=$(echo "$line" | sed -n "s/.*desc = '\([^']*\)'.*/\1/p")

		if [[ -n "$key" ]] && [[ -n "$desc" ]]; then
			local mode_label="n"
			case "$mode" in
			n) mode_label="n" ;;
			v) mode_label="v" ;;
			x) mode_label="x" ;;
			"") mode_label="all" ;;
			*) mode_label="$mode" ;;
			esac
			printf "| \`%s\` | %s | %s |\n" "$key" "$mode_label" "$desc"
		fi
	done

	# Parse maps() block entries: { '<key>', expr, 'description' },
	grep -E "^\s*\{ '<" "$keymaps_file" | grep -v "^\s*--" | while IFS= read -r line; do
		local key desc
		key=$(echo "$line" | sed -n "s/.*{ '\([^']*\)',.*$/\1/p")
		# Get the last single-quoted string as the description
		desc=$(echo "$line" | sed -n "s/.*,\s*'\([^']*\)'\s*}.*/\1/p")

		if [[ -n "$key" ]] && [[ -n "$desc" ]]; then
			printf "| \`%s\` | n | %s |\n" "$key" "$desc"
		fi
	done
}

parse_plugin_keymaps() {
	local plugins_dir="$DOTFILES_DIR/src/nvim/lua/plugins"

	if [[ ! -d "$plugins_dir" ]]; then
		return
	fi

	# Scan plugin files for vim.keymap.set or map() calls with descriptions
	find "$plugins_dir" -name "*.lua" -type f | sort | while IFS= read -r plugin_file; do
		local filename
		filename=$(basename "$plugin_file" .lua)

		local found_keymaps=false
		while IFS= read -r line; do
			local key desc
			# Pattern: vim.keymap.set('mode', '<key>', ..., { desc = '...' })
			key=$(echo "$line" | sed -n "s/.*vim\.keymap\.set('[^']*', '\([^']*\)'.*/\1/p")
			desc=$(echo "$line" | sed -n "s/.*desc = '\([^']*\)'.*/\1/p")

			if [[ -n "$key" ]] && [[ -n "$desc" ]]; then
				local mode
				mode=$(echo "$line" | sed -n "s/.*vim\.keymap\.set('\([^']*\)'.*/\1/p")
				printf "| \`%s\` | %s | %s | %s |\n" "$key" "${mode:-n}" "$desc" "$filename"
			fi
		done < <(grep -E "vim\.keymap\.set" "$plugin_file" 2>/dev/null | grep -v "^\s*--" || true)
	done
}

parse_which_key_groups() {
	local wk_file="$DOTFILES_DIR/src/nvim/lua/plugins/which-key.lua"

	if [[ ! -f "$wk_file" ]]; then
		log_warning "which-key.lua not found"
		return
	fi

	# Extract entries from the groups table: { '<key>', 'label' }
	# The groups table is between "local groups = {" and "local descs = {"
	sed -n '/local groups = {/,/local descs = {/p' "$wk_file" | \
		grep -E "^\s*\{ '<" | while IFS= read -r line; do
		local key label
		key=$(echo "$line" | sed -n "s/.*{ '\([^']*\)', '\([^']*\)' }.*/\1/p")
		label=$(echo "$line" | sed -n "s/.*{ '[^']*', '\([^']*\)' }.*/\1/p")

		if [[ -n "$key" ]] && [[ -n "$label" ]]; then
			printf "| \`%s\` | %s |\n" "$key" "$label"
		fi
	done
}

parse_shell_aliases() {
	local zshrc="$DOTFILES_DIR/src/.zshrc"

	if [[ ! -f "$zshrc" ]]; then
		log_warning ".zshrc not found"
		return
	fi

	grep -E "^alias " "$zshrc" | while IFS= read -r line; do
		local name expansion
		name=$(echo "$line" | sed "s/^alias \([^=]*\)=.*/\1/")
		expansion=$(echo "$line" | sed "s/^alias [^=]*=//")
		# Remove surrounding quotes
		expansion=$(echo "$expansion" | sed "s/^['\"]//;s/['\"]$//")
		# Escape pipe characters for markdown
		expansion=$(echo "$expansion" | sed 's/|/\\|/g')

		printf "| \`%s\` | \`%s\` |\n" "$name" "$expansion"
	done
}

parse_shell_functions() {
	local zshrc="$DOTFILES_DIR/src/.zshrc"

	if [[ ! -f "$zshrc" ]]; then
		return
	fi

	grep -E "^[a-zA-Z_][a-zA-Z0-9_]*\(\)" "$zshrc" | while IFS= read -r line; do
		local name
		name=$(echo "$line" | sed "s/() {.*//;s/() .*//" | tr -d ' ')

		if [[ -n "$name" ]]; then
			printf "| \`%s\` |\n" "$name"
		fi
	done
}

parse_shell_keybindings() {
	local zshrc="$DOTFILES_DIR/src/.zshrc"

	if [[ ! -f "$zshrc" ]]; then
		return
	fi

	grep -E "^bindkey " "$zshrc" | while IFS= read -r line; do
		local key func
		key=$(echo "$line" | sed -n "s/^bindkey '\([^']*\)' .*/\1/p")
		func=$(echo "$line" | sed -n "s/^bindkey '[^']*' \(.*\)/\1/p")

		if [[ -n "$key" ]] && [[ -n "$func" ]]; then
			printf "| \`%s\` | %s |\n" "$key" "$func"
		fi
	done
}

parse_ghostty_keybindings() {
	local config="$DOTFILES_DIR/src/ghostty/config"

	if [[ ! -f "$config" ]]; then
		return
	fi

	grep -E "^keybind" "$config" | while IFS= read -r line; do
		local binding
		binding=$(echo "$line" | sed "s/^keybind\s*=\s*//")

		if [[ -n "$binding" ]]; then
			local key action
			key=$(echo "$binding" | cut -d= -f1 | tr -d ' ')
			action=$(echo "$binding" | cut -d= -f2- | tr -d ' ')
			printf "| \`%s\` | %s |\n" "$key" "$action"
		fi
	done
}

parse_zellij_keybindings() {
	local config="$DOTFILES_DIR/src/zellij/config.kdl"

	if [[ ! -f "$config" ]]; then
		return
	fi

	# Extract bind lines: bind "key" { action; }
	grep -E '^\s*bind "' "$config" | while IFS= read -r line; do
		local key action
		key=$(echo "$line" | sed -n 's/.*bind "\([^"]*\)".*/\1/p')
		action=$(echo "$line" | sed -n 's/.*{ \(.*\) }/\1/p' | sed 's/;$//')

		if [[ -n "$key" ]] && [[ -n "$action" ]]; then
			printf "| \`%s\` | %s |\n" "$key" "$action"
		fi
	done
}

generate_manual() {
	local output_file="$1"

	{
		echo "# Dotfiles Manual"
		echo ""
		echo "> Auto-generated by \`generate-manual.sh\`. Re-run after keymap or alias changes."
		echo ""
		echo "---"
		echo ""

		echo "## Which-Key Groups"
		echo ""
		echo "| Prefix | Label |"
		echo "|--------|-------|"
		parse_which_key_groups
		echo ""

		echo "## Neovim Keymaps (core)"
		echo ""
		echo "| Key | Mode | Description |"
		echo "|-----|------|-------------|"
		parse_neovim_keymaps
		echo ""

		local plugin_keymaps
		plugin_keymaps=$(parse_plugin_keymaps)
		if [[ -n "$plugin_keymaps" ]]; then
			echo "## Neovim Keymaps (plugins)"
			echo ""
			echo "| Key | Mode | Description | Plugin |"
			echo "|-----|------|-------------|--------|"
			echo "$plugin_keymaps"
			echo ""
		fi

		echo "## Shell Aliases"
		echo ""
		echo "| Alias | Expands To |"
		echo "|-------|------------|"
		parse_shell_aliases
		echo ""

		local shell_funcs
		shell_funcs=$(parse_shell_functions)
		if [[ -n "$shell_funcs" ]]; then
			echo "## Shell Functions"
			echo ""
			echo "| Function |"
			echo "|----------|"
			echo "$shell_funcs"
			echo ""
		fi

		echo "## Shell Keybindings (zsh)"
		echo ""
		echo "| Key | Action |"
		echo "|-----|--------|"
		parse_shell_keybindings
		echo ""

		local ghostty_keys
		ghostty_keys=$(parse_ghostty_keybindings)
		if [[ -n "$ghostty_keys" ]]; then
			echo "## Ghostty Keybindings"
			echo ""
			echo "| Key | Action |"
			echo "|-----|--------|"
			echo "$ghostty_keys"
			echo ""
		fi

		local zellij_keys
		zellij_keys=$(parse_zellij_keybindings)
		if [[ -n "$zellij_keys" ]]; then
			echo "## Zellij Keybindings"
			echo ""
			echo "| Key | Action |"
			echo "|-----|--------|"
			echo "$zellij_keys"
			echo ""
		fi
	} >"$output_file"
}

main() {
	local output_file="$DEFAULT_OUTPUT"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--output)
			output_file="$2"
			shift 2
			;;
		--help | -h)
			show_help
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
		esac
	done

	mkdir -p "$(dirname "$output_file")"

	log_info "Generating dotfiles manual..."
	log_info "Scanning: keymaps, which-key, aliases, functions, keybindings"

	generate_manual "$output_file"

	local line_count
	line_count=$(wc -l <"$output_file" | tr -d ' ')

	log_success "Manual generated: $output_file ($line_count lines)"

	json_output "$(json_obj "output_file" "$output_file" "line_count" "$line_count")"
}

main "$@"
