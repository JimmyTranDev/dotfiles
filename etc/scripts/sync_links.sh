#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$SCRIPT_DIR/common/utility.sh"
source "$SCRIPT_DIR/common/logging.sh"
set -e

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d_%H%M%S)"
DRY_RUN=false

get_common_links() {
	local links=(
		"$HOME/Programming/JimmyTranDev/nvim $HOME/.config/nvim"
		"$DOTFILES_ROOT/src/yazi $HOME/.config/yazi"
		"$DOTFILES_ROOT/src/lazygit $HOME/.config/lazygit"
		"$DOTFILES_ROOT/src/.zshrc $HOME/.zshrc"
		"$DOTFILES_ROOT/src/.ideavimrc $HOME/.ideavimrc"
		"$DOTFILES_ROOT/src/.gitignore_global $HOME/.gitignore_global"
		"$DOTFILES_ROOT/src/btop $HOME/.config/btop"
		"$DOTFILES_ROOT/src/starship.toml $HOME/.config/starship.toml"
		"$DOTFILES_ROOT/src/kitty $HOME/.config/kitty"
		"$DOTFILES_ROOT/src/opencode $HOME/.config/opencode"
		"$DOTFILES_ROOT/src/git/hooks $HOME/.config/git/hooks"
		"$DOTFILES_ROOT/src/espanso $HOME/.config/espanso"
	)
	printf '%s\n' "${links[@]}"
}

get_macos_links() {
	get_common_links
	local links=(
		"$DOTFILES_ROOT/src/Brewfile $HOME/Brewfile"
		"$DOTFILES_ROOT/src/skhd $HOME/.config/skhd"
		"$DOTFILES_ROOT/src/yabai $HOME/.config/yabai"
		"$DOTFILES_ROOT/src/ghostty $HOME/.config/ghostty"
	)
	printf '%s\n' "${links[@]}"
}

get_linux_links() {
	get_common_links
	local links=(
		"$DOTFILES_ROOT/src/hypr $HOME/.config/hypr"
	)
	printf '%s\n' "${links[@]}"
}

get_platform_links() {
	if [ "$(uname)" == "Darwin" ]; then
		get_macos_links
	elif [ "$(uname)" == "Linux" ]; then
		get_linux_links
	else
		log_error "Unsupported platform: $(uname)"
		exit 1
	fi
}

backup_existing() {
	local dest="$1"
	if [ -L "$dest" ]; then
		return
	fi
	if [ -e "$dest" ]; then
		mkdir -p "$BACKUP_DIR"
		local backup_path="$BACKUP_DIR/$(basename "$dest")"
		cp -a "$dest" "$backup_path"
		log_info "Backed up $(basename "$dest") -> $backup_path"
	fi
}

create_links() {
	if [ "$DRY_RUN" = true ]; then
		log_header "Dry run - showing what would be linked..."
	else
		log_header "Creating dotfiles symlinks..."
	fi

	mkdir -p "$HOME/.config"
	mkdir -p "$HOME/.config/git"

	local success_count=0
	local skip_count=0
	local total_count=0

	while IFS= read -r entry; do
		[ -z "$entry" ] && continue

		local src=$(echo "$entry" | awk '{print $1}')
		local dest=$(echo "$entry" | awk '{print $2}')

		total_count=$((total_count + 1))

		if [ ! -e "$src" ]; then
			log_warning "Skipping $(basename "$dest") (source not found: $src)"
			continue
		fi

		if [ -L "$dest" ]; then
			local current_target=$(readlink "$dest")
			if [ "$current_target" = "$src" ]; then
				skip_count=$((skip_count + 1))
				if [ "$DRY_RUN" = true ]; then
					log_info "Already linked: $(basename "$dest")"
				fi
				continue
			fi
		fi

		if [ "$DRY_RUN" = true ]; then
			log_info "Would link: $src -> $dest"
			success_count=$((success_count + 1))
			continue
		fi

		local dest_dir=$(dirname "$dest")
		mkdir -p "$dest_dir"

		backup_existing "$dest"

		if [ -e "$dest" ] || [ -L "$dest" ]; then
			rm -rf "$dest"
		fi

		if ln -s "$src" "$dest"; then
			log_success "Created link: $(basename "$dest")"
			success_count=$((success_count + 1))
		else
			log_error "Failed to create link: $src -> $dest"
		fi
	done <<<"$(get_platform_links)"

	echo
	log_info "${EMOJI_LINK} Linking Summary:"
	if [ "$DRY_RUN" = true ]; then
		log_info "  ${EMOJI_EYE} Would create: $success_count links"
		log_info "  ${EMOJI_SUCCESS} Already correct: $skip_count links"
		log_info "  ${EMOJI_INFO} Total: $total_count entries"
	else
		log_info "  ${EMOJI_SUCCESS} Created: $success_count links"
		log_info "  ${EMOJI_INFO} Skipped (already correct): $skip_count"
		log_info "  ${EMOJI_INFO} Total: $total_count entries"
	fi

	if [ $success_count -lt $((total_count - skip_count)) ]; then
		log_warning "Some links failed - check the output above for details"
	fi

	if [ "$DRY_RUN" = false ]; then
		log_info "Setting global git hooks path..."
		git config --global core.hooksPath "$HOME/.config/git/hooks"
		log_success "Global git hooks configured"
	fi
}

usage() {
	echo "Usage: $(basename "$0") [--dry-run]"
	echo ""
	echo "Options:"
	echo "  --dry-run    Show what would be linked without making changes"
	echo "  --help       Show this help message"
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run)
			DRY_RUN=true
			shift
			;;
		--help)
			usage
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			usage
			exit 1
			;;
		esac
	done

	create_links
}

main "$@"
