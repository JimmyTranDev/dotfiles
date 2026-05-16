#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

install_node() {
	local dir="${1:-.}"
	local frozen="${2:-false}"
	local pm
	pm=$(detect_node_package_manager "$dir")

	log_info "Package manager: $pm"

	local cmd
	if [[ "$frozen" == "true" ]]; then
		case "$pm" in
		pnpm) cmd="pnpm install --frozen-lockfile" ;;
		yarn) cmd="yarn install --frozen-lockfile" ;;
		bun) cmd="bun install --frozen-lockfile" ;;
		npm) cmd="npm ci" ;;
		esac
	else
		cmd="$pm install"
	fi

	local exit_code=0
	(cd "$dir" && eval "$cmd") || exit_code=$?

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "$pm")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"frozen" "$frozen")"
}

install_maven() {
	local dir="${1:-.}"
	log_info "Build tool: mvn"
	local cmd="mvn dependency:resolve -q"
	local exit_code=0
	(cd "$dir" && mvn dependency:resolve -q) || exit_code=$?

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "maven")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"frozen" "false")"
}

install_gradle() {
	local dir="${1:-.}"
	local gradle_cmd="gradle"
	if [[ -f "$dir/gradlew" ]]; then
		gradle_cmd="./gradlew"
	fi
	log_info "Build tool: $gradle_cmd"
	local cmd="$gradle_cmd dependencies --quiet"
	local exit_code=0
	(cd "$dir" && $gradle_cmd dependencies --quiet) || exit_code=$?

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "gradle")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"frozen" "false")"
}

install_python() {
	local dir="${1:-.}"
	local cmd=""
	local pm=""
	if [[ -f "$dir/pyproject.toml" ]] && command -v poetry &>/dev/null; then
		pm="poetry"
		cmd="poetry install"
	elif [[ -f "$dir/requirements.txt" ]]; then
		pm="pip"
		cmd="pip install -r requirements.txt"
	else
		log_error "No requirements.txt or pyproject.toml found"
		return 1
	fi
	log_info "Build tool: $pm"
	local exit_code=0
	(cd "$dir" && eval "$cmd") || exit_code=$?

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "$pm")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"frozen" "false")"
}

install_go() {
	local dir="${1:-.}"
	log_info "Build tool: go"
	local cmd="go mod download"
	local exit_code=0
	(cd "$dir" && go mod download) || exit_code=$?

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "go")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"frozen" "false")"
}

install_rust() {
	local dir="${1:-.}"
	log_info "Build tool: cargo"
	local cmd="cargo fetch"
	local exit_code=0
	(cd "$dir" && cargo fetch) || exit_code=$?

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "cargo")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"frozen" "false")"
}

show_help() {
	log_info "Usage: install-deps.sh [OPTIONS] [directory]"
	log_info ""
	log_info "Auto-detect package manager and install dependencies."
	log_info ""
	log_info "Options:"
	log_info "  --frozen    Use lockfile-only install (CI mode)"
	log_info "  --help      Show this help message"
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
