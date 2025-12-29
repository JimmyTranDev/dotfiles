#!/bin/bash

# Storage Sync Script
# Sync secrets to Backblaze B2 cloud storage
# Usage: ./sync.sh [options]

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

# Default options
DRY_RUN=false
INTERACTIVE=true

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
        log_info "Run init.sh first to create the secrets directory"
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

# Interactive mode selection
interactive_sync() {
    log_header "Interactive Cloud Storage Sync"
    echo
    
    log_info "Sync configuration:"
    log_info "  • Source: $SECRETS_PATH"
    log_info "  • Target: b2://$B2_BUCKET_NAME"
    log_info "  • Excludes: .m2/repository files"
    echo
    
    echo -e "${CYAN}Sync mode options:${NC}"
    echo -e "${YELLOW}[1]${NC} Dry run - Preview changes without syncing"
    echo -e "${YELLOW}[2]${NC} Full sync - Upload files to cloud storage"
    echo
    
    echo -e "${YELLOW}Select sync mode [1/2]:${NC} "
    read -r mode
    
    case "$mode" in
        1)
            DRY_RUN=true
            ;;
        2)
            DRY_RUN=false
            ;;
        *)
            log_error "Invalid selection: $mode"
            return 1
            ;;
    esac
    
    if [ "$DRY_RUN" = true ]; then
        echo
        log_info "${EMOJI_EYE} Dry run: Checking what would be synced..."
    else
        echo
        log_warning "This will upload your secrets to cloud storage."
        echo -e "${YELLOW}Continue? [y/N]:${NC} "
        read -r confirm
        
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]')
        if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
            log_info "Sync cancelled"
            return 0
        fi
    fi
    
    return 0
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
    
    # Interactive mode if enabled
    if [ "$INTERACTIVE" = true ]; then
        if ! interactive_sync; then
            return 1
        fi
    fi
    
    # Authorize with B2
    if ! authorize_b2; then
        return 1
    fi
    
    # Perform sync
    if ! perform_sync "$DRY_RUN"; then
        return 1
    fi
    
    echo
    log_info "${EMOJI_CLOUD} Sync Summary:"
    if [ "$DRY_RUN" = true ]; then
        log_info "  • Mode: Dry run (preview only)"
        log_info "  • Files were not actually uploaded"
        log_info "  • Check output above for sync preview"
    else
        log_info "  • Mode: Full sync"
        log_info "  • Files uploaded to Backblaze B2"
        log_info "  • Backup completed successfully"
    fi
    echo
    
    return 0
}

# Show help
show_help() {
    cat << EOF
☁️ Storage Sync Script

Sync secrets directory to Backblaze B2 cloud storage.

USAGE:
    $0 [options]

OPTIONS:
    --dry-run         Preview changes without actually syncing
    --non-interactive Run without interactive prompts
    -h, --help        Show this help message

ENVIRONMENT VARIABLES (Required):
    B2_BUCKET_NAME         Backblaze B2 bucket name
    B2_APPLICATION_KEY_ID  Backblaze B2 application key ID
    B2_APPLICATION_KEY     Backblaze B2 application key

DIRECTORY:
    Secrets synced from: $SECRETS_PATH

FEATURES:
    • Excludes .m2/repository files (Maven cache)
    • Replaces newer files on conflict
    • Interactive mode for safety
    • Dry run support for preview

EXAMPLES:
    $0                      # Interactive sync
    $0 --dry-run            # Preview what would be synced
    $0 --non-interactive    # Sync without prompts (full sync)
    $0 --help               # Show this help

REQUIREMENTS:
    • b2 CLI tool (pip install b2)
    • B2 environment variables set
    • Secrets directory initialized

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                INTERACTIVE=false
                shift
                ;;
            --non-interactive)
                INTERACTIVE=false
                shift
                ;;
            -h|--help|help)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo
                show_help
                exit 1
                ;;
        esac
    done
}

# Main function
main() {
    parse_args "$@"
    
    if ! sync_secrets; then
        exit 1
    fi
}

# Run main function with all arguments
main "$@"