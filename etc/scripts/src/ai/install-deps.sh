#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"

install_node() {
	local dir="${1:-.}"
	local frozen="${2:-false}"
	local pm
	pm=$(detect_node_package_manager "$dir")

	log_info "Package manager: $pm"

	if [[ "$frozen" == "true" ]]; then
		case "$pm" in
		pnpm) (cd "$dir" && pnpm install --frozen-lockfile) ;;
		yarn) (cd "$dir" && yarn install --frozen-lockfile) ;;
		bun) (cd "$dir" && bun install --frozen-lockfile) ;;
		npm) (cd "$dir" && npm ci) ;;
		esac
	else
		(cd "$dir" && $pm install)
	fi
}

install_maven() {
	local dir="${1:-.}"
	log_info "Build tool: mvn"
	(cd "$dir" && mvn dependency:resolve -q)
}

install_gradle() {
	local dir="${1:-.}"
	local gradle_cmd="gradle"
	if [[ -f "$dir/gradlew" ]]; then
		gradle_cmd="./gradlew"
	fi
	log_info "Build tool: $gradle_cmd"
	(cd "$dir" && $gradle_cmd dependencies --quiet)
}

install_python() {
	local dir="${1:-.}"
	if [[ -f "$dir/pyproject.toml" ]] && command -v poetry &>/dev/null; then
		log_info "Build tool: poetry"
		(cd "$dir" && poetry install)
	elif [[ -f "$dir/requirements.txt" ]]; then
		log_info "Build tool: pip"
		(cd "$dir" && pip install -r requirements.txt)
	else
		log_error "No requirements.txt or pyproject.toml found"
		return 1
	fi
}

install_go() {
	local dir="${1:-.}"
	log_info "Build tool: go"
	(cd "$dir" && go mod download)
}

install_rust() {
	local dir="${1:-.}"
	log_info "Build tool: cargo"
	(cd "$dir" && cargo fetch)
}

show_help() {
	echo "Usage: install-deps.sh [OPTIONS] [directory]"
	echo ""
	echo "Auto-detect package manager and install dependencies."
	echo ""
	echo "Options:"
	echo "  --frozen    Use lockfile-only install (CI mode)"
	echo "  --help      Show this help message"
}

main() {
	local dir="."
	local frozen="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--frozen)
			frozen="true"
			shift
			;;
		--help)
			show_help
			exit 0
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	log_header "Installing Dependencies" "📦"

	if [[ -f "$dir/package.json" ]]; then
		install_node "$dir" "$frozen"
	elif [[ -f "$dir/pom.xml" ]]; then
		install_maven "$dir"
	elif [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
		install_gradle "$dir"
	elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]]; then
		install_python "$dir"
	elif [[ -f "$dir/go.mod" ]]; then
		install_go "$dir"
	elif [[ -f "$dir/Cargo.toml" ]]; then
		install_rust "$dir"
	else
		log_error "Could not detect project type for dependency installation"
		return 1
	fi

	log_success "Dependencies installed"
}

main "$@"
