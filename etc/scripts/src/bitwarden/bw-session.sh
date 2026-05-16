#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"

MAX_ATTEMPTS=3

show_help() {
	cat <<'EOF'
Usage: bw-session.sh [options]

Unlock Bitwarden vault and export BW_SESSION.

OPTIONS:
  --status    Check current authentication status
  -h, --help  Show this help message

USAGE IN SHELL:
  Source this script to export BW_SESSION:
    eval "$(bw-session.sh)"

  Or add a shell function to .zshrc:
    bwu() { eval "$(path/to/bw-session.sh)"; }
EOF
}

check_status() {
	if ! command -v bw &>/dev/null; then
		log_error "Bitwarden CLI (bw) not found. Install with: brew install bitwarden-cli"
		exit 1
	fi

	local status
	status=$(bw status 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null || echo "unknown")
	echo "$status"
}

unlock_vault() {
	local status
	status=$(check_status)

	case "$status" in
	"unlocked")
		log_info "Vault already unlocked"
		local session
		session=$(bw unlock --raw 2>/dev/null || true)
		if [[ -n "$session" ]]; then
			echo "export BW_SESSION=\"$session\""
		fi
		return 0
		;;
	"locked")
		log_info "Vault is locked. Unlocking..."
		;;
	"unauthenticated")
		log_info "Not logged in. Logging in..."
		bw login || {
			log_error "Login failed"
			exit 1
		}
		;;
	*)
		log_error "Unknown vault status: $status"
		exit 1
		;;
	esac

	local attempt=1
	while [[ $attempt -le $MAX_ATTEMPTS ]]; do
		local session
		session=$(bw unlock --raw 2>/dev/null)

		if [[ -n "$session" ]]; then
			log_success "Vault unlocked successfully"
			echo "export BW_SESSION=\"$session\""
			return 0
		fi

		log_error "Wrong password (attempt $attempt/$MAX_ATTEMPTS)"
		attempt=$((attempt + 1))
	done

	log_error "Failed to unlock after $MAX_ATTEMPTS attempts"
	exit 1
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--status)
			local status
			status=$(check_status)
			log_info "Vault status: $status"
			exit 0
			;;
		-h | --help) show_help; exit 0 ;;
		*) log_error "Unknown option: $1"; show_help; exit 1 ;;
		esac
	done

	unlock_vault
}

main "$@"
