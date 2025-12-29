#!/bin/bash

# Secrets Sync Script
# Sync secrets to Backblaze B2 cloud storage

source "$HOME/Programming/dotfiles/etc/scripts/common/utility.sh"
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS_PATH="$HOME/Programming/secrets"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emoji for better UX
EMOJI_SUCCESS="✓"
EMOJI_ERROR="❌"
EMOJI_WARNING="⚠️"
EMOJI_INFO="ℹ️"
EMOJI_CLOUD="☁️"
EMOJI_EYE="👁"

# Required B2 environment variables
B2_REQUIRED_VARS=(
    "B2_BUCKET_NAME"
    "B2_APPLICATION_KEY_ID"
    "B2_APPLICATION_KEY"
)

# Function to log messages
log_info() {
    echo -e "${CYAN}${EMOJI_INFO} $1${NC}"
}

log_success() {
    echo -e "${GREEN}${EMOJI_SUCCESS} $1${NC}"
}

log_error() {
    echo -e "${RED}${EMOJI_ERROR} $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}${EMOJI_WARNING} $1${NC}"
}

log_header() {
    echo -e "${BLUE}${EMOJI_CLOUD} $1${NC}"
}

# Validate B2 credentials
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
        echo -e "${CYAN}  export B2_BUCKET_NAME=\"your-bucket-name\"${NC}"
        echo -e "${CYAN}  export B2_APPLICATION_KEY_ID=\"your-key-id\"${NC}"
        echo -e "${CYAN}  export B2_APPLICATION_KEY=\"your-application-key\"${NC}"
        echo
        return 1
    fi
    
    log_success "B2 credentials validated"
    return 0
}

# Check if b2 CLI is installed
check_b2_cli() {
    if ! command -v b2 >/dev/null 2>&1; then
        log_error "b2 CLI not found"
        log_info "Install with: pip install b2"
        return 1
    fi
    
    log_success "b2 CLI found"
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
    
    if b2 account authorize "$B2_APPLICATION_KEY_ID" "$B2_APPLICATION_KEY" >/dev/null 2>&1; then
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
        "b2://$B2_BUCKET_NAME"
        "--exclude-regex"
        ".*\\.m2/repository/.*"
        "--replace-newer"
    )
    
    if [ "$is_dry_run" = true ]; then
        args+=("--dry-run")
        log_header "Performing dry run sync..."
    else
        log_header "Performing full sync..."
    fi
    
    log_info "Source: $SECRETS_PATH"
    log_info "Target: b2://$B2_BUCKET_NAME"
    log_info "Excludes: .m2/repository files"
    echo
    
    # Execute sync command
    if b2 "${args[@]}"; then
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

# Main sync function
sync_secrets() {
    # Validation checks
    if ! validate_b2_credentials; then
        return 1
    fi
    
    if ! check_b2_cli; then
        return 1
    fi
    
    if ! check_secrets_directory; then
        return 1
    fi
    
    # Authorize with B2
    if ! authorize_b2; then
        return 1
    fi
    
    # Perform sync (always full sync, never dry run)
    if ! perform_sync false; then
        return 1
    fi
    
    echo
    log_info "${EMOJI_CLOUD} Sync Summary:"
    log_info "  • Mode: Full sync"
    log_info "  • Files uploaded to Backblaze B2"
    log_info "  • Backup completed successfully"
    echo
    
    return 0
}

# Main function
main() {
    if ! sync_secrets; then
        exit 1
    fi
}

# Run main function with all arguments
main "$@"