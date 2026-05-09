#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"

scan_secrets_heuristic() {
    local dir="${1:-.}"
    local found=0

    log_header "Secret Scanning (heuristic)" "🔑"

    local env_files
    env_files=$(git -C "$dir" ls-files '*.env' '.env.*' 2>/dev/null | grep -v '.example' | grep -v '.template' || echo "")
    if [[ -n "$env_files" ]]; then
        log_warning "Tracked .env files found:"
        echo "$env_files" | while IFS= read -r f; do
            echo "  - $f"
        done
        found=1
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
            log_warning "Potential secret pattern found ($pattern):"
            echo "$matches" | head -5
            found=1
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        log_success "No secrets detected (heuristic scan)"
    fi

    return $found
}

scan_secrets_tool() {
    local dir="${1:-.}"

    if command -v trufflehog &>/dev/null; then
        log_header "Secret Scanning (trufflehog)" "🔑"
        (cd "$dir" && trufflehog filesystem --directory . --only-verified 2>/dev/null) || true
        return 0
    fi

    if command -v gitleaks &>/dev/null; then
        log_header "Secret Scanning (gitleaks)" "🔑"
        (cd "$dir" && gitleaks detect --source . 2>/dev/null) || true
        return 0
    fi

    return 1
}

run_dep_audit() {
    local dir="${1:-.}"

    log_header "Dependency Audit" "📦"

    if [[ -f "$dir/package.json" ]]; then
        local pm
        pm=$(detect_node_package_manager "$dir")
        if [[ -z "$pm" ]]; then
            pm="npm"
        fi
        (cd "$dir" && $pm audit 2>/dev/null) || log_warning "Audit found vulnerabilities (see above)"
    elif [[ -f "$dir/pom.xml" ]]; then
        if command -v mvn &>/dev/null; then
            (cd "$dir" && mvn org.owasp:dependency-check-maven:check -q 2>/dev/null) || log_warning "OWASP check not configured or found vulnerabilities"
        fi
    elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]]; then
        if command -v pip-audit &>/dev/null; then
            (cd "$dir" && pip-audit 2>/dev/null) || log_warning "pip-audit found vulnerabilities"
        elif command -v safety &>/dev/null; then
            (cd "$dir" && safety check 2>/dev/null) || log_warning "Safety check found vulnerabilities"
        else
            log_warning "Install pip-audit or safety for Python vulnerability scanning"
        fi
    elif [[ -f "$dir/go.mod" ]]; then
        (cd "$dir" && go list -m -json all 2>/dev/null | go run golang.org/x/vuln/cmd/govulncheck@latest ./... 2>/dev/null) || log_warning "Go vulnerability check not available"
    else
        log_info "No supported package manager found for dependency audit"
    fi
}

show_help() {
    echo "Usage: security-scan.sh [directory]"
    echo ""
    echo "Combined secret scanning and dependency audit."
    echo "Uses trufflehog/gitleaks if available, falls back to heuristic patterns."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
}

main() {
    local dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) show_help; exit 0 ;;
            *) dir="$1"; shift ;;
        esac
    done

    log_header "Security Scan" "🛡️"

    if ! scan_secrets_tool "$dir"; then
        scan_secrets_heuristic "$dir" || true
    fi

    run_dep_audit "$dir"

    log_success "Security scan complete"
}

main "$@"
