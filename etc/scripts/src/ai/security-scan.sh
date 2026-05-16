#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

SECRETS_FOUND=0
ENV_FILES_JSON=""
SECRET_PATTERNS_JSON=""
SCAN_TOOL="heuristic"
AUDIT_OUTPUT=""
AUDIT_EXIT_CODE=0

scan_secrets_heuristic() {
	local dir="${1:-.}"

	log_info "Running heuristic secret scan"

	local env_files
	env_files=$(git -C "$dir" ls-files '*.env' '.env.*' 2>/dev/null | grep -v '.example' | grep -v '.template' || echo "")
	if [[ -n "$env_files" ]]; then
		log_warning "Tracked .env files found"
		SECRETS_FOUND=1
		while IFS= read -r f; do
			if [[ -n "$f" ]]; then
				local escaped
				escaped=$(json_escape "$f")
				if [[ -n "$ENV_FILES_JSON" ]]; then
					ENV_FILES_JSON="${ENV_FILES_JSON},${escaped}"
				else
					ENV_FILES_JSON="$escaped"
				fi
			fi
		done <<<"$env_files"
	fi

	local secret_patterns=(
		'AKIA[0-9A-Z]{16}'
		'AIza[0-9A-Za-z_-]{35}'
		'sk-[0-9a-zA-Z]{20,}'
		'ghp_[0-9a-zA-Z]{36}'
		'gho_[0-9a-zA-Z]{36}'
		'xoxb-[0-9]+-[0-9A-Za-z]+'
		'sk_live_[0-9a-zA-Z]{24,}'
		'sq0atp-[0-9A-Za-z_-]{22}'
	)

	for pattern in "${secret_patterns[@]}"; do
		local matches
		matches=$(git -C "$dir" grep -rn -E "$pattern" -- ':(exclude)*.lock' ':(exclude)node_modules' ':(exclude)*.min.js' 2>/dev/null || echo "")
		if [[ -n "$matches" ]]; then
			log_warning "Potential secret pattern found ($pattern)"
			SECRETS_FOUND=1
			local match_obj
			match_obj=$(json_obj "pattern" "$pattern" "sample" "$(echo "$matches" | head -1)")
			if [[ -n "$SECRET_PATTERNS_JSON" ]]; then
				SECRET_PATTERNS_JSON="${SECRET_PATTERNS_JSON},${match_obj}"
			else
				SECRET_PATTERNS_JSON="$match_obj"
			fi
		fi
	done

	if [[ "$SECRETS_FOUND" -eq 0 ]]; then
		log_success "No secrets detected (heuristic scan)"
	fi
}

scan_secrets_tool() {
	local dir="${1:-.}"

	if command -v trufflehog &>/dev/null; then
		SCAN_TOOL="trufflehog"
		log_info "Running trufflehog scan"
		local output
		output=$( (cd "$dir" && trufflehog filesystem --directory . --only-verified 2>/dev/null) || true)
		if [[ -n "$output" ]]; then
			SECRETS_FOUND=1
		fi
		return 0
	fi

	if command -v gitleaks &>/dev/null; then
		SCAN_TOOL="gitleaks"
		log_info "Running gitleaks scan"
		local output
		output=$( (cd "$dir" && gitleaks detect --source . 2>/dev/null) || true)
		if [[ -n "$output" ]]; then
			SECRETS_FOUND=1
		fi
		return 0
	fi

	return 1
}

run_dep_audit() {
	local dir="${1:-.}"

	log_info "Running dependency audit"

	if [[ -f "$dir/package.json" ]]; then
		local pm
		pm=$(detect_node_package_manager "$dir")
		if [[ -z "$pm" ]]; then
			pm="npm"
		fi
		AUDIT_OUTPUT=$( (cd "$dir" && $pm audit 2>&1) || true)
		AUDIT_EXIT_CODE=$?
	elif [[ -f "$dir/pom.xml" ]]; then
		if command -v mvn &>/dev/null; then
			AUDIT_OUTPUT=$( (cd "$dir" && mvn org.owasp:dependency-check-maven:check -q 2>&1) || true)
			AUDIT_EXIT_CODE=$?
		fi
	elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]]; then
		if command -v pip-audit &>/dev/null; then
			AUDIT_OUTPUT=$( (cd "$dir" && pip-audit 2>&1) || true)
			AUDIT_EXIT_CODE=$?
		elif command -v safety &>/dev/null; then
			AUDIT_OUTPUT=$( (cd "$dir" && safety check 2>&1) || true)
			AUDIT_EXIT_CODE=$?
		else
			log_warning "Install pip-audit or safety for Python vulnerability scanning"
		fi
	elif [[ -f "$dir/go.mod" ]]; then
		AUDIT_OUTPUT=$( (cd "$dir" && go list -m -json all 2>/dev/null | go run golang.org/x/vuln/cmd/govulncheck@latest ./... 2>&1) || true)
		AUDIT_EXIT_CODE=$?
	else
		log_info "No supported package manager found for dependency audit"
	fi
}

show_help() {
	echo "Usage: security-scan.sh [directory]"
	echo ""
	echo "Combined secret scanning and dependency audit. Outputs JSON."
	echo ""
	echo "Options:"
	echo "  --help    Show this help message"
}

main() {
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
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

	log_info "Starting security scan"

	if ! scan_secrets_tool "$dir"; then
		scan_secrets_heuristic "$dir"
	fi

	run_dep_audit "$dir"

	log_success "Security scan complete"

	json_output $(json_obj_raw \
		"secrets_found" "$SECRETS_FOUND" \
		"env_files_tracked" "[${ENV_FILES_JSON}]" \
		"secret_patterns_found" "[${SECRET_PATTERNS_JSON}]" \
		"scan_tool" "$(json_escape "$SCAN_TOOL")" \
		"audit_output" "$(json_escape "$AUDIT_OUTPUT")" \
		"audit_exit_code" "$AUDIT_EXIT_CODE")
}

main "$@"
