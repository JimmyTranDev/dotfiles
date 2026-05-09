#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/detect.sh"

run_linter() {
    local dir="${1:-.}"
    local fix="${2:-false}"
    local linter
    linter=$(detect_linter "$dir")

    log_header "Lint Check" "🔍"
    log_info "Linter: $linter"

    case "$linter" in
        eslint)
            local pm
            pm=$(detect_node_runner "$dir")
            if [[ "$fix" == "true" ]]; then
                (cd "$dir" && $pm eslint . --fix)
            else
                (cd "$dir" && $pm eslint .)
            fi
            ;;
        biome)
            local pm
            pm=$(detect_node_runner "$dir")
            if [[ "$fix" == "true" ]]; then
                (cd "$dir" && $pm biome check --write .)
            else
                (cd "$dir" && $pm biome check .)
            fi
            ;;
        ruff)
            if [[ "$fix" == "true" ]]; then
                (cd "$dir" && ruff check --fix .)
            else
                (cd "$dir" && ruff check .)
            fi
            ;;
        golangci-lint)
            if [[ "$fix" == "true" ]]; then
                (cd "$dir" && golangci-lint run --fix ./...)
            else
                (cd "$dir" && golangci-lint run ./...)
            fi
            ;;
        clippy)
            if [[ "$fix" == "true" ]]; then
                (cd "$dir" && cargo clippy --fix --allow-dirty)
            else
                (cd "$dir" && cargo clippy)
            fi
            ;;
        checkstyle-maven)
            (cd "$dir" && mvn checkstyle:check -q)
            ;;
        checkstyle-gradle)
            local gradle_cmd="gradle"
            if [[ -f "$dir/gradlew" ]]; then
                gradle_cmd="./gradlew"
            fi
            (cd "$dir" && $gradle_cmd checkstyleMain --quiet)
            ;;
        *)
            log_error "Could not detect linter"
            return 1
            ;;
    esac
}

show_help() {
    echo "Usage: lint-check.sh [OPTIONS] [directory]"
    echo ""
    echo "Auto-detect linter and run lint check."
    echo ""
    echo "Options:"
    echo "  --fix     Auto-fix issues where supported"
    echo "  --help    Show this help message"
}

main() {
    local dir="."
    local fix="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --fix) fix="true"; shift ;;
            --help) show_help; exit 0 ;;
            *) dir="$1"; shift ;;
        esac
    done

    run_linter "$dir" "$fix"
}

main "$@"
