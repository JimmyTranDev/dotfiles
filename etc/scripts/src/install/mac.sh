#!/bin/bash

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALL_DIR/../../utils/logging.sh"

main() {
	log_header "Running macOS setup..."

	if command -v brew >/dev/null 2>&1; then
		read -rp "Run brew bundle install? [y/N] " answer </dev/tty
		if [[ "$answer" =~ ^[Yy]$ ]]; then
			log_info "Installing Homebrew packages..."
			brew bundle --file="$HOME/Brewfile" check ||
				brew bundle --file="$HOME/Brewfile" install
			brew bundle --file="$HOME/Brewfile" cleanup --force
		else
			log_info "Skipping Homebrew packages"
		fi
	else
		log_error "Homebrew not found. Please install Homebrew first:"
		echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
		exit 1
	fi

	log_info "Applying macOS system preferences..."

	defaults write com.apple.universalaccess reduceMotion -bool true

	defaults write NSGlobalDomain KeyRepeat -int 2
	defaults write NSGlobalDomain InitialKeyRepeat -int 15

	defaults write com.apple.dock orientation -string "left"
	defaults write com.apple.dock autohide -bool true
	killall Dock

	for i in {1..9}; do
		defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add "$((17 + i))" \
			"<dict><key>enabled</key><true/><key>value</key><dict><key>parameters</key><array><integer>$((48 + i))</integer><integer>$((17 + i))</integer><integer>262144</integer></array><key>type</key><string>standard</string></dict></dict>"
	done

	log_success "macOS setup completed"

	start_macos_services
}

start_macos_services() {
	if command -v yabai >/dev/null 2>&1; then
		log_info "Starting yabai service..."
		yabai --start-service
		log_success "yabai service started"
	else
		log_warning "yabai not found, skipping service start"
	fi
	if command -v skhd >/dev/null 2>&1; then
		log_info "Starting skhd service..."
		skhd --start-service
		log_success "skhd service started"
	else
		log_warning "skhd not found, skipping service start"
	fi
	if brew list postgresql@17 &>/dev/null || brew list postgresql &>/dev/null; then
		log_info "Starting PostgreSQL service..."
		brew services start postgresql@17 2>/dev/null || brew services start postgresql 2>/dev/null || log_warning "Failed to start PostgreSQL service"
		log_success "PostgreSQL service started"
	else
		log_warning "PostgreSQL not found, skipping service start"
	fi
}

main "$@"
