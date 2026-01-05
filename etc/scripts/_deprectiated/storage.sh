#!/bin/bash

# =============================================================================
# Storage Management Script
# Cloud storage and secrets management utilities
# =============================================================================

set -e

# =============================================================================
# Configuration
# =============================================================================

SECRETS_PATH="$HOME/Programming/secrets"

# Template files to create
TEMPLATE_FILES=(
  "technical_links.json:{}"
  "useful_links.json:{}"
)

# =============================================================================
# Helper Functions  
# =============================================================================

# Print colored output
print_info() {
  echo -e "\033[0;34m[INFO]\033[0m $1"
}

print_success() {
  echo -e "\033[0;32m[SUCCESS]\033[0m $1"
}

print_error() {
  echo -e "\033[0;31m[ERROR]\033[0m $1"
}

print_warning() {
  echo -e "\033[0;33m[WARN]\033[0m $1"
}

# Get B2 environment variables
get_b2_credentials() {
  if [[ -z "$PRI_B2_BUCKET_NAME" || -z "$PRI_B2_APPLICATION_KEY_ID" || -z "$PRI_B2_APPLICATION_KEY" ]]; then
    return 1
  fi
  return 0
}

# Create template file if it doesn't exist
create_template_file() {
  local filename="$1"
  local content="$2"
  local file_path="$SECRETS_PATH/$filename"
  
  if [[ -f "$file_path" ]]; then
    return 0
  fi
  
  if ! echo "$content" > "$file_path"; then
    print_error "Could not create file: $file_path"
    return 1
  fi
  
  print_info "Created template file: $file_path"
  return 0
}

# Ensure directory exists
ensure_directory() {
  local dir_path="$1"
  
  if [[ ! -d "$dir_path" ]]; then
    if ! mkdir -p "$dir_path"; then
      print_error "Failed to create directory: $dir_path"
      return 1
    fi
  fi
  
  return 0
}

# Build B2 sync command
build_sync_command() {
  local local_path="$1"
  
  echo "b2 account authorize \"$PRI_B2_APPLICATION_KEY_ID\" \"$PRI_B2_APPLICATION_KEY\" && b2 sync \"$local_path\" \"b2://$PRI_B2_BUCKET_NAME\" --excludeRegex \".*\\.m2/repository/.*\""
}

# =============================================================================
# Main Functions
# =============================================================================

# Initialize secrets directory with template files
init_secrets_directory() {
  print_info "Initializing secrets directory..."
  
  if ! ensure_directory "$SECRETS_PATH"; then
    print_error "Failed to create secrets directory"
    return 1
  fi
  
  local success_count=0
  local total_count=${#TEMPLATE_FILES[@]}
  
  for template in "${TEMPLATE_FILES[@]}"; do
    local filename="${template%:*}"
    local content="${template#*:}"
    if create_template_file "$filename" "$content"; then
      ((success_count++))
    fi
  done
  
  if [[ $success_count -eq $total_count ]]; then
    print_success "Secrets directory initialized successfully!"
    return 0
  else
    print_warning "Partial initialization: $success_count/$total_count files created"
    return 1
  fi
}

# Sync secrets to cloud storage using B2
sync_secrets() {
  print_info "Syncing secrets to cloud storage..."
  
  if ! get_b2_credentials; then
    print_error "B2 environment variables not set (PRI_B2_BUCKET_NAME, PRI_B2_APPLICATION_KEY_ID, PRI_B2_APPLICATION_KEY)"
    return 1
  fi
  
  if [[ ! -d "$SECRETS_PATH" ]]; then
    print_error "Secrets directory does not exist: $SECRETS_PATH"
    return 1
  fi
  
  local sync_cmd
  sync_cmd=$(build_sync_command "$SECRETS_PATH")
  
  print_info "Executing B2 sync..."
  if eval "$sync_cmd"; then
    print_success "Secrets synchronized successfully"
    return 0
  else
    print_error "Failed to sync secrets to cloud storage"
    return 1
  fi
}

# Show help
show_help() {
  cat << EOF
Storage Management Script

USAGE:
  $(basename "$0") <command>

COMMANDS:
  init       Initialize secrets directory with template files
  sync       Sync secrets to cloud storage using B2
  help       Show this help message

ENVIRONMENT VARIABLES:
  PRI_B2_BUCKET_NAME         - Backblaze B2 bucket name
  PRI_B2_APPLICATION_KEY_ID  - Backblaze B2 application key ID  
  PRI_B2_APPLICATION_KEY     - Backblaze B2 application key

EXAMPLES:
  $(basename "$0") init    # Create secrets directory and template files
  $(basename "$0") sync    # Sync secrets to cloud storage
EOF
}

# =============================================================================
# Main Script Logic
# =============================================================================

main() {
  local command="${1:-}"
  
  case "$command" in
    "init")
      init_secrets_directory
      ;;
    "sync") 
      sync_secrets
      ;;
    "help"|"-h"|"--help"|"")
      show_help
      ;;
    *)
      print_error "Unknown command: $command"
      echo
      show_help
      exit 1
      ;;
  esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi