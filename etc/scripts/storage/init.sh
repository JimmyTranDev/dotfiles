#!/bin/bash

# Storage Initialization Script
# Initialize secrets directory with template files
# Usage: ./init.sh

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
EMOJI_CONFIG="⚙️"

# Template files to create
declare -A TEMPLATE_FILES=(
    ["technical_links.json"]="{}"
    ["useful_links.json"]="{}"
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
    echo -e "${BLUE}${EMOJI_CONFIG} $1${NC}"
}

# Create a template file if it doesn't exist
create_template_file() {
    local filename="$1"
    local content="$2"
    local file_path="$SECRETS_PATH/$filename"
    
    # Check if file already exists
    if [ -f "$file_path" ]; then
        log_warning "File already exists: $filename"
        return 0
    fi
    
    # Create the file
    if echo "$content" > "$file_path"; then
        log_success "Created template file: $filename"
        return 0
    else
        log_error "Failed to create file: $filename"
        return 1
    fi
}

# Initialize secrets directory
init_secrets_directory() {
    log_header "Initializing secrets directory..."
    echo
    
    log_info "Target directory: $SECRETS_PATH"
    
    # Create secrets directory if it doesn't exist
    if ! mkdir -p "$SECRETS_PATH"; then
        log_error "Failed to create secrets directory: $SECRETS_PATH"
        return 1
    fi
    
    log_success "Secrets directory ready: $SECRETS_PATH"
    echo
    
    log_info "Creating template files..."
    local success_count=0
    local total_count=${#TEMPLATE_FILES[@]}
    
    # Create each template file
    for filename in "${!TEMPLATE_FILES[@]}"; do
        local content="${TEMPLATE_FILES[$filename]}"
        if create_template_file "$filename" "$content"; then
            ((success_count++))
        fi
    done
    
    echo
    log_info "${EMOJI_CONFIG} Initialization Summary:"
    log_info "  • Target directory: $SECRETS_PATH"
    log_info "  • Template files processed: $total_count"
    log_info "  • Successfully created: $success_count"
    log_info "  • Already existed: $((total_count - success_count))"
    
    if [ $success_count -gt 0 ]; then
        echo
        log_success "Secrets directory initialized successfully!"
        log_info "You can now add your secrets and configuration files"
        log_info "Use the sync script to backup to cloud storage"
    else
        echo
        log_warning "No new files created - directory was already initialized"
        log_info "All template files already exist"
    fi
    
    return 0
}

# Show help
show_help() {
    cat << EOF
🔧 Storage Initialization Script

This script initializes the secrets directory with template files.

USAGE:
    $0 [options]

OPTIONS:
    -h, --help    Show this help message

DIRECTORY:
    Secrets will be created at: $SECRETS_PATH

TEMPLATE FILES:
    • technical_links.json - For technical bookmarks and resources
    • useful_links.json - For useful links and references

EXAMPLES:
    $0               # Initialize secrets directory
    $0 --help        # Show this help

NEXT STEPS:
    1. Add your secrets and configuration files
    2. Use sync.sh to backup to cloud storage
    3. Set B2 environment variables for cloud sync

EOF
}

# Main function
main() {
    case "${1:-}" in
        -h|--help|help)
            show_help
            ;;
        "")
            # Confirmation prompt
            echo -e "${YELLOW}${EMOJI_WARNING} This will initialize the secrets directory at:${NC}"
            echo -e "${CYAN}  $SECRETS_PATH${NC}"
            echo
            echo -e "${CYAN}Template files to be created:${NC}"
            for filename in "${!TEMPLATE_FILES[@]}"; do
                echo -e "${CYAN}  • $filename${NC}"
            done
            echo
            
            echo -e "${YELLOW}Continue with initialization? [Y/n]:${NC} "
            read -r response
            
            response=$(echo "$response" | tr '[:upper:]' '[:lower:]')
            if [[ "$response" == "n" || "$response" == "no" ]]; then
                log_info "Initialization cancelled"
                exit 0
            fi
            
            echo
            init_secrets_directory
            ;;
        *)
            log_error "Unknown option: $1"
            echo
            show_help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"