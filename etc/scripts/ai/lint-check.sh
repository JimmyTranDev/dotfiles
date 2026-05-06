#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"

detect_package_manager() {
    local dir="${1:-.}"

    if [[ -f "$dir/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "$dir/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$dir/bun.lockb" ]] || [[ -f "$dir/bun.lock" ]]; then
        echo "bun"
    else
        echo "npx"
    fi
}

detect_linter() {
    local dir="${1:-.}"

    if [[ -f "$dir/biome.json" ]] || [[ -f "$dir/biome.jsonc" ]]; then
        echo "biome"
        return
    fi

    if ls "$dir"/eslint.config.* 2>/dev/null | head -1 &>/dev/null; then
        echo "eslint"
        return
    fi

    if [[ -f "$dir/.eslintrc" ]] || [[ -f "$dir/.eslintrc.js" ]] || [[ -f "$dir/.eslintrc.json" ]] || [[ -f "$dir/.eslintrc.yml" ]]; then
        echo "eslint"
        return
    fi

    if [[ -f "$dir/pyproject.toml" ]] && grep -q "ruff" "$dir/pyproject.toml" 2>/dev/null; then
        echo "ruff"
        return
    fi

    if [[ -f "$dir/.golangci.yml" ]] || [[ -f "$dir/.golangci.yaml" ]]; then
        echo "golangci-lint"
        return
    fi

    if [[ -f "$dir/Cargo.toml" ]]; then
        echo "clippy"
        return
    fi

    if [[ -f "$dir/pom.xml" ]] && grep -q "checkstyle" "$dir/pom.xml" 2>/dev/null; then
        echo "checkstyle-maven"
        return
    fi

    if [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
        local gradle_file="$dir/build.gradle"
        if [[ -f "$dir/build.gradle.kts" ]]; then
            gradle_file="$dir/build.gradle.kts"
        fi
        if grep -q "checkstyle" "$gradle_file" 2>/dev/null; then
            echo "checkstyle-gradle"
            return
        fi
    fi

    echo "unknown"
}

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
            pm=$(detect_package_manager "$dir")
            if [[ "$fix" == "true" ]]; then
                (cd "$dir" && $pm eslint . --fix)
            else
                (cd "$dir" && $pm eslint .)
            fi
            ;;
        biome)
            local pm
            pm=$(detect_package_manager "$dir")
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
