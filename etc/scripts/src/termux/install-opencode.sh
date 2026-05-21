#!/bin/bash
set -e

# Install or update OpenCode on Termux using the community native binary.
# https://github.com/guysoft/opencode-termux/releases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || echo "")"
LOGGING_SH="${SCRIPT_DIR:+$SCRIPT_DIR/../../utils/logging.sh}"
if [[ -n "$LOGGING_SH" && -f "$LOGGING_SH" ]]; then
	source "$LOGGING_SH"
else
	log_header() { echo "==> $1"; }
	log_info() { echo "[INFO] $1"; }
	log_success() { echo "[OK] $1"; }
	log_warning() { echo "[WARN] $1"; }
	log_error() { echo "[ERROR] $1" >&2; }
fi

RELEASES_API="https://api.github.com/repos/guysoft/opencode-termux/releases/latest"

show_help() {
	cat <<'EOF'
Usage: install-opencode.sh [options]

Install or update OpenCode on Termux (aarch64 Android only).
Uses the community-maintained native binary from guysoft/opencode-termux.

OPTIONS:
  --force       Reinstall even if already installed
  --version VER Install a specific version (default: latest)
  -h, --help    Show this help message
EOF
}

get_latest_version() {
	local tag
	tag="$(curl -fsSL "$RELEASES_API" 2>/dev/null | jq -r '.tag_name // empty')"
	if [[ -z "$tag" ]]; then
		log_warning "Could not fetch latest version from GitHub API"
		echo ""
		return
	fi
	# Tag format: v0.0.0-1.3.13 -> extract the version after the last dash
	echo "${tag##*-}"
}

main() {
	local force=false
	local version=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--force) force=true; shift ;;
		--version) version="$2"; shift 2 ;;
		-h | --help) show_help; exit 0 ;;
		*) log_error "Unknown option: $1"; show_help; exit 1 ;;
		esac
	done

	local arch
	arch="$(uname -m)"
	if [[ "$arch" != "aarch64" ]]; then
		log_error "OpenCode native binary only supports aarch64 (detected: $arch)"
		log_info "Workaround: use proot-distro ubuntu and install from there"
		exit 1
	fi

	if [[ "$force" != "true" ]] && command -v opencode &>/dev/null; then
		local current
		current="$(opencode --version 2>/dev/null || echo "unknown")"
		log_info "OpenCode already installed (version: $current)"
		log_info "Use --force to reinstall"
		exit 0
	fi

	if [[ -z "$version" ]]; then
		log_info "Fetching latest version..."
		version="$(get_latest_version)"
		if [[ -z "$version" ]]; then
			version="1.3.13"
			log_warning "Falling back to version $version"
		fi
	fi

	local zip_name="opencode-${version}-android-aarch64.zip"
	local url="https://github.com/guysoft/opencode-termux/releases/download/v0.0.0-${version}/${zip_name}"
	local tmp_dir
	tmp_dir="$(mktemp -d)"
	trap 'rm -rf "$tmp_dir"' EXIT

	log_header "Installing OpenCode v${version}"

	if ! command -v unzip &>/dev/null; then
		log_info "Installing unzip..."
		pkg install -y unzip || {
			log_error "Failed to install unzip"
			exit 1
		}
	fi

	if ! command -v curl &>/dev/null; then
		log_info "Installing curl..."
		pkg install -y curl || {
			log_error "Failed to install curl"
			exit 1
		}
	fi

	log_info "Downloading from $url..."
	if ! curl -fsSL -o "$tmp_dir/$zip_name" "$url"; then
		log_error "Download failed. Check if version $version exists at:"
		log_error "  https://github.com/guysoft/opencode-termux/releases"
		exit 1
	fi

	unzip -o -q "$tmp_dir/$zip_name" -d "$tmp_dir"
	chmod +x "$tmp_dir/opencode"
	mv "$tmp_dir/opencode" "$PREFIX/bin/opencode"

	log_success "OpenCode v${version} installed to $PREFIX/bin/opencode"
	log_info ""
	log_info "Setup your API key:"
	log_info "  export ANTHROPIC_API_KEY=\"your-key-here\""
	log_info ""
	log_info "Then run: opencode"
}

main "$@"
