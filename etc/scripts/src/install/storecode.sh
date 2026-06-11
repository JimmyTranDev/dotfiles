#!/bin/bash

set -e

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$INSTALL_DIR/../../utils/logging.sh"

check_prerequisites() {
	local missing=0

	if ! command -v gcloud >/dev/null 2>&1; then
		log_error "gcloud CLI not found. Install from: https://cloud.google.com/sdk/docs/install"
		missing=1
	else
		log_info "gcloud CLI found: $(gcloud --version 2>/dev/null | head -1)"
	fi

	if ! command -v gh >/dev/null 2>&1; then
		log_error "GitHub CLI (gh) not found. Install from: https://cli.github.com"
		missing=1
	else
		local gh_version
		gh_version="$(gh --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')"
		local required_version="2.85.0"

		if printf '%s\n%s\n' "$required_version" "$gh_version" | sort -V | head -1 | grep -q "^${required_version}$"; then
			log_info "GitHub CLI found: v${gh_version}"
		else
			log_error "GitHub CLI v${gh_version} is too old. Need v${required_version} or later."
			missing=1
		fi

		if ! gh auth status >/dev/null 2>&1; then
			log_error "GitHub CLI not authenticated. Run: gh auth login"
			missing=1
		else
			log_info "GitHub CLI authenticated"
		fi
	fi

	return $missing
}

install_storecode() {
	log_info "Installing storecode via gh release..."
	gh release download --repo storebrand-digital/storecode -p 'install.sh' -O - | sh
	log_success "storecode installed"
}

verify_storecode() {
	if command -v storecode >/dev/null 2>&1; then
		log_success "storecode verified: $(storecode --version 2>/dev/null || echo 'installed')"
		return 0
	fi

	# The installer adds ~/.local/bin to PATH but current shell may not have it yet
	if [[ -x "$HOME/.local/bin/storecode" ]]; then
		log_success "storecode installed at ~/.local/bin/storecode (restart terminal or source shell rc to use)"
		return 0
	fi

	log_error "storecode installation could not be verified"
	return 1
}

main() {
	log_header "Setting up storecode..."

	if command -v storecode >/dev/null 2>&1; then
		log_info "storecode already installed: $(storecode --version 2>/dev/null || echo 'installed')"
		read -rp "Reinstall storecode? [y/N] " answer </dev/tty
		if [[ ! "$answer" =~ ^[Yy]$ ]]; then
			log_info "Skipping storecode install"
			return 0
		fi
	elif [[ -x "$HOME/.local/bin/storecode" ]]; then
		log_info "storecode found at ~/.local/bin/storecode but not on PATH"
		read -rp "Reinstall storecode? [y/N] " answer </dev/tty
		if [[ ! "$answer" =~ ^[Yy]$ ]]; then
			log_info "Skipping storecode install"
			return 0
		fi
	fi

	if ! check_prerequisites; then
		log_error "Prerequisites not met. Please install the missing tools and try again."
		exit 1
	fi

	install_storecode
	verify_storecode

	log_info "To complete setup, run 'storecode' inside a git repo."
	log_info "On first run it will prompt for GCP authentication (admin-cloud account)."
	log_success "storecode setup completed"
}

main "$@"
