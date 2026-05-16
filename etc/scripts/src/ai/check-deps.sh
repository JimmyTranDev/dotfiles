#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

check_node_deps() {
	local dir="${1:-.}"

	local pm
	pm=$(detect_node_package_manager "$dir")
	if [[ -z "$pm" ]]; then
		pm="npm"
	fi

	log_info "Package manager: $pm"

	log_header "Outdated Dependencies" "📦"
	local outdated_output=""
	local outdated_exit_code=0
	outdated_output=$((cd "$dir" && $pm outdated 2>&1) || true)
	outdated_exit_code=${PIPESTATUS[0]:-0}

	log_header "Security Audit" "🔒"
	local audit_output=""
	local audit_exit_code=0
	if [[ "$pm" == "pnpm" ]]; then
		audit_output=$((cd "$dir" && pnpm audit 2>&1) || true)
	elif [[ "$pm" == "yarn" ]]; then
		audit_output=$((cd "$dir" && yarn audit 2>&1) || true)
	else
		audit_output=$((cd "$dir" && npm audit 2>&1) || true)
	fi
	audit_exit_code=${PIPESTATUS[0]:-0}

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "$pm")" \
		"outdated_output" "$(json_escape "$outdated_output")" \
		"audit_output" "$(json_escape "$audit_output")" \
		"outdated_exit_code" "$outdated_exit_code" \
		"audit_exit_code" "$audit_exit_code")"
}

check_maven_deps() {
	local dir="${1:-.}"

	log_header "Outdated Dependencies" "📦"
	local outdated_output=""
	local outdated_exit_code=0
	outdated_output=$((cd "$dir" && mvn versions:display-dependency-updates -q 2>&1) || true)
	outdated_exit_code=${PIPESTATUS[0]:-0}

	log_header "Dependency Vulnerabilities" "🔒"
	local audit_output=""
	local audit_exit_code=0
	if command -v mvn &>/dev/null; then
		audit_output=$((cd "$dir" && mvn org.owasp:dependency-check-maven:check -q 2>&1) || true)
		audit_exit_code=${PIPESTATUS[0]:-0}
	fi

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "maven")" \
		"outdated_output" "$(json_escape "$outdated_output")" \
		"audit_output" "$(json_escape "$audit_output")" \
		"outdated_exit_code" "$outdated_exit_code" \
		"audit_exit_code" "$audit_exit_code")"
}

check_gradle_deps() {
	local dir="${1:-.}"
	local gradle_cmd="gradle"
	if [[ -f "$dir/gradlew" ]]; then
		gradle_cmd="./gradlew"
	fi

	log_header "Dependencies" "📦"
	local outdated_output=""
	local outdated_exit_code=0
	outdated_output=$((cd "$dir" && $gradle_cmd dependencies --configuration compileClasspath --quiet 2>&1) || true)
	outdated_exit_code=${PIPESTATUS[0]:-0}

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "gradle")" \
		"outdated_output" "$(json_escape "$outdated_output")" \
		"audit_output" "$(json_escape "")" \
		"outdated_exit_code" "$outdated_exit_code" \
		"audit_exit_code" "0")"
}

check_python_deps() {
	local dir="${1:-.}"

	log_header "Outdated Dependencies" "📦"
	local outdated_output=""
	local outdated_exit_code=0
	outdated_output=$((cd "$dir" && pip list --outdated 2>&1) || true)
	outdated_exit_code=${PIPESTATUS[0]:-0}

	log_header "Security Audit" "🔒"
	local audit_output=""
	local audit_exit_code=0
	if command -v safety &>/dev/null; then
		audit_output=$((cd "$dir" && safety check 2>&1) || true)
		audit_exit_code=${PIPESTATUS[0]:-0}
	elif command -v pip-audit &>/dev/null; then
		audit_output=$((cd "$dir" && pip-audit 2>&1) || true)
		audit_exit_code=${PIPESTATUS[0]:-0}
	else
		log_warning "Install 'safety' or 'pip-audit' for vulnerability scanning"
	fi

	json_output "$(json_obj_raw \
		"package_manager" "$(json_escape "pip")" \
		"outdated_output" "$(json_escape "$outdated_output")" \
		"audit_output" "$(json_escape "$audit_output")" \
		"outdated_exit_code" "$outdated_exit_code" \
		"audit_exit_code" "$audit_exit_code")"
}

main() {
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			log_info "Usage: check-deps.sh [directory]"
			log_info ""
			log_info "Check for outdated dependencies and run security audit."
			exit 0
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	log_header "Dependency Check"

	if [[ -f "$dir/package.json" ]]; then
		check_node_deps "$dir"
	elif [[ -f "$dir/pom.xml" ]]; then
		check_maven_deps "$dir"
	elif [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
		check_gradle_deps "$dir"
	elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]]; then
		check_python_deps "$dir"
	else
		log_error "Could not detect project type for dependency checking"
		json_output '{"package_manager":"unknown","outdated_output":"","audit_output":"","outdated_exit_code":1,"audit_exit_code":1}'
		return 1
	fi
}

main "$@"
