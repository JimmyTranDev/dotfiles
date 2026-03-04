#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "$SCRIPT_DIR/common/utility.sh"
source "$SCRIPT_DIR/common/logging.sh"
set -e
SECRETS_PATH="$HOME/Programming/JimmyTranDev/secrets"

B2_REQUIRED_VARS=(
	"PRI_B2_BUCKET_NAME"
	"PRI_B2_APPLICATION_KEY_ID"
	"PRI_B2_APPLICATION_KEY"
)

validate_b2_credentials() {
	log_info "Validating B2 credentials..."

	local missing_vars=()

	for var in "${B2_REQUIRED_VARS[@]}"; do
		if [ -z "${!var}" ]; then
			missing_vars+=("$var")
		fi
	done

	if [ ${#missing_vars[@]} -gt 0 ]; then
		log_error "Missing required B2 environment variables:"
		for var in "${missing_vars[@]}"; do
			echo -e "  ${RED}✗${NC} $var"
		done
		echo
		log_info "Please set these environment variables:"
		echo -e "${CYAN}  export PRI_B2_BUCKET_NAME=\"your-bucket-name\"${NC}"
		echo -e "${CYAN}  export PRI_B2_APPLICATION_KEY_ID=\"your-key-id\"${NC}"
		echo -e "${CYAN}  export PRI_B2_APPLICATION_KEY=\"your-application-key\"${NC}"
		echo
		return 1
	fi

	log_success "B2 credentials validated"
	return 0
}

# Install b2 CLI based on the current platform
install_b2() {
	log_info "Installing b2 CLI..."

	case "$(uname -s)" in
	Linux)
		if command -v pacman >/dev/null 2>&1; then
			sudo pacman -S --needed --noconfirm backblaze-b2
		else
			log_error "Unsupported Linux distribution (no pacman found)"
			return 1
		fi
		;;
	Darwin)
		if command -v brew >/dev/null 2>&1; then
			brew install b2-tools
		else
			log_error "Homebrew not found. Install it first: https://brew.sh"
			return 1
		fi
		;;
	*)
		log_error "Unsupported platform: $(uname -s)"
		return 1
		;;
	esac
}

# Determine the correct b2 command name (macOS uses 'b2', Arch uses 'backblaze-b2')
detect_b2_command() {
	if command -v b2 >/dev/null 2>&1; then
		B2_CMD="b2"
	elif command -v backblaze-b2 >/dev/null 2>&1; then
		B2_CMD="backblaze-b2"
	else
		log_warning "b2 CLI not found, attempting to install..."
		if ! install_b2; then
			log_error "Failed to install b2 CLI"
			return 1
		fi

		# Re-detect after install
		if command -v b2 >/dev/null 2>&1; then
			B2_CMD="b2"
		elif command -v backblaze-b2 >/dev/null 2>&1; then
			B2_CMD="backblaze-b2"
		else
			log_error "b2 CLI still not found after installation"
			return 1
		fi
	fi

	log_success "b2 CLI found: $B2_CMD"
	return 0
}

# Check if secrets directory exists
check_secrets_directory() {
	if [ ! -d "$SECRETS_PATH" ]; then
		log_error "Secrets directory does not exist: $SECRETS_PATH"
		log_info "Run init_secrets.sh first to create the secrets directory"
		return 1
	fi

	log_success "Secrets directory found: $SECRETS_PATH"
	return 0
}

# Setup B2 command environment to avoid terminal issues
setup_b2_env() {
	export COLUMNS=80
	export LINES=24
	export TERM=xterm
	export NO_COLOR=1
}

# Authorize with B2
authorize_b2() {
	log_info "Authorizing with B2..."

	setup_b2_env

	if B2_APPLICATION_KEY_ID="$PRI_B2_APPLICATION_KEY_ID" B2_APPLICATION_KEY="$PRI_B2_APPLICATION_KEY" $B2_CMD account authorize >/dev/null 2>&1; then
		log_success "B2 authorization successful"
		return 0
	else
		log_error "B2 authorization failed"
		log_info "Check your B2 credentials and try again"
		return 1
	fi
}

# Perform the sync operation
perform_sync() {
	local is_dry_run="$1"

	setup_b2_env

	# Build sync command arguments
	local args=(
		"sync"
		"$SECRETS_PATH"
		"b2://$PRI_B2_BUCKET_NAME"
		"--exclude-regex"
		".*\\.m2/repository/.*"
		"--replace-newer"
		"--compare-versions"
		"none"
		"--exclude-all-symlinks"
		"--no-progress"
	)

	if [ "$is_dry_run" = true ]; then
		args+=("--dry-run")
		log_header "Performing dry run sync..."
	else
		log_header "Performing full sync..."
	fi

	log_info "Source: $SECRETS_PATH"
	log_info "Target: b2://$PRI_B2_BUCKET_NAME"
	log_info "Excludes: .m2/repository files"
	echo

	# Execute sync command
	if $B2_CMD "${args[@]}"; then
		if [ "$is_dry_run" = true ]; then
			log_success "Dry run completed successfully"
			log_info "No files were actually uploaded"
		else
			log_success "Sync completed successfully"
			log_info "Files have been uploaded to B2 cloud storage"
		fi
		return 0
	else
		if [ "$is_dry_run" = true ]; then
			log_error "Dry run failed"
		else
			log_error "Sync failed"
		fi
		return 1
	fi
}

# Download secrets from B2 to local
perform_download() {
	setup_b2_env

	log_header "Downloading secrets from B2..."
	log_info "Source: b2://$PRI_B2_BUCKET_NAME"
	log_info "Target: $SECRETS_PATH"
	echo

	# Create the secrets directory
	mkdir -p "$SECRETS_PATH"

	# Build download sync command arguments (B2 -> local)
	local args=(
		"sync"
		"b2://$PRI_B2_BUCKET_NAME"
		"$SECRETS_PATH"
		"--exclude-regex"
		".*\\.m2/repository/.*"
		"--exclude-all-symlinks"
		"--no-progress"
		"--skip-newer"
	)

	if $B2_CMD "${args[@]}"; then
		log_success "Download completed successfully"
		log_info "Files have been downloaded from B2 cloud storage"
		return 0
	else
		log_warning "Download encountered issues (some files may have been skipped)"
		return 0
	fi
}

# Main sync function
sync_secrets() {
	local mode="$1"

	# Validation checks
	if ! validate_b2_credentials; then
		return 1
	fi

	if ! detect_b2_command; then
		return 1
	fi

	# Authorize with B2
	if ! authorize_b2; then
		return 1
	fi

	# Determine sync mode from argument, default to both
	case "$mode" in
	download) ;;
	upload) ;;
	"")
		mode="both"
		;;
	*)
		log_error "Unknown mode: $mode"
		log_info "Usage: sync_secrets.sh [upload|download]"
		return 1
		;;
	esac

	# Download phase
	if [ "$mode" = "download" ] || [ "$mode" = "both" ]; then
		if [ ! -d "$SECRETS_PATH" ]; then
			log_info "Secrets directory not found at $SECRETS_PATH"
		fi
		log_info "Downloading secrets from B2..."
		echo

		if ! perform_download; then
			return 1
		fi

		echo
	fi

	# Upload phase
	if [ "$mode" = "upload" ] || [ "$mode" = "both" ]; then
		if ! check_secrets_directory; then
			return 1
		fi

		# Perform upload sync
		if ! perform_sync false; then
			return 1
		fi

		echo
	fi

	# Summary
	log_info "${EMOJI_CLOUD} Sync Summary:"
	case "$mode" in
	download)
		log_info "  • Mode: Download"
		log_info "  • Files downloaded from Backblaze B2"
		log_info "  • Secrets restored to $SECRETS_PATH"
		;;
	upload)
		log_info "  • Mode: Upload"
		log_info "  • Files uploaded to Backblaze B2"
		log_info "  • Backup completed successfully"
		;;
	both)
		log_info "  • Mode: Download + Upload"
		log_info "  • Files downloaded from Backblaze B2"
		log_info "  • Files uploaded to Backblaze B2"
		log_info "  • Full sync completed successfully"
		;;
	esac
	echo

	return 0
}

# Main function
main() {
	if ! sync_secrets "$@"; then
		exit 1
	fi
}

# Run main function with all arguments
main "$@"
