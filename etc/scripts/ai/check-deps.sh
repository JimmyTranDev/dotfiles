#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"

check_node_deps() {
    local dir="${1:-.}"

    local pm="npm"
    if [[ -f "$dir/pnpm-lock.yaml" ]]; then
        pm="pnpm"
    elif [[ -f "$dir/yarn.lock" ]]; then
        pm="yarn"
    fi

    log_info "Package manager: $pm"

    log_header "Outdated Dependencies" "📦"
    (cd "$dir" && $pm outdated 2>/dev/null) || log_warning "Could not check outdated packages"

    log_header "Security Audit" "🔒"
    if [[ "$pm" == "pnpm" ]]; then
        (cd "$dir" && pnpm audit 2>/dev/null) || log_warning "Audit found vulnerabilities (see above)"
    elif [[ "$pm" == "yarn" ]]; then
        (cd "$dir" && yarn audit 2>/dev/null) || log_warning "Audit found vulnerabilities (see above)"
    else
        (cd "$dir" && npm audit 2>/dev/null) || log_warning "Audit found vulnerabilities (see above)"
    fi
}

check_maven_deps() {
    local dir="${1:-.}"

    log_header "Outdated Dependencies" "📦"
    (cd "$dir" && mvn versions:display-dependency-updates -q 2>/dev/null) || log_warning "Could not check Maven updates"

    log_header "Dependency Vulnerabilities" "🔒"
    if command -v mvn &>/dev/null; then
        (cd "$dir" && mvn org.owasp:dependency-check-maven:check -q 2>/dev/null) || log_warning "OWASP check not configured"
    fi
}

check_gradle_deps() {
    local dir="${1:-.}"
    local gradle_cmd="gradle"
    if [[ -f "$dir/gradlew" ]]; then
        gradle_cmd="./gradlew"
    fi

    log_header "Dependencies" "📦"
    (cd "$dir" && $gradle_cmd dependencies --configuration compileClasspath --quiet 2>/dev/null) || log_warning "Could not list dependencies"
}

check_python_deps() {
    local dir="${1:-.}"

    log_header "Outdated Dependencies" "📦"
    (cd "$dir" && pip list --outdated 2>/dev/null) || log_warning "Could not check outdated packages"

    log_header "Security Audit" "🔒"
    if command -v safety &>/dev/null; then
        (cd "$dir" && safety check 2>/dev/null) || log_warning "Safety check found vulnerabilities"
    elif command -v pip-audit &>/dev/null; then
        (cd "$dir" && pip-audit 2>/dev/null) || log_warning "pip-audit found vulnerabilities"
    else
        log_warning "Install 'safety' or 'pip-audit' for vulnerability scanning"
    fi
}

main() {
    local dir="${1:-.}"

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
        return 1
    fi
}

main "$@"
