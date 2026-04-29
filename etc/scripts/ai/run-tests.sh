#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"

detect_test_framework() {
    local dir="${1:-.}"

    if [[ -f "$dir/pom.xml" ]]; then
        if grep -q "surefire" "$dir/pom.xml" 2>/dev/null || grep -q "junit" "$dir/pom.xml" 2>/dev/null; then
            echo "maven-surefire"
            return
        fi
        echo "maven"
        return
    fi

    if [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
        echo "gradle"
        return
    fi

    if [[ -f "$dir/package.json" ]]; then
        if grep -q '"vitest"' "$dir/package.json" 2>/dev/null; then
            echo "vitest"
        elif grep -q '"jest"' "$dir/package.json" 2>/dev/null; then
            echo "jest"
        elif grep -q '"mocha"' "$dir/package.json" 2>/dev/null; then
            echo "mocha"
        else
            echo "npm-test"
        fi
        return
    fi

    if [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/pytest.ini" ]] || [[ -f "$dir/setup.cfg" ]]; then
        echo "pytest"
        return
    fi

    if [[ -f "$dir/go.mod" ]]; then
        echo "go-test"
        return
    fi

    if [[ -f "$dir/Cargo.toml" ]]; then
        echo "cargo-test"
        return
    fi

    echo "unknown"
}

detect_package_manager() {
    local dir="${1:-.}"

    if [[ -f "$dir/pnpm-lock.yaml" ]]; then
        echo "pnpm"
    elif [[ -f "$dir/yarn.lock" ]]; then
        echo "yarn"
    elif [[ -f "$dir/bun.lockb" ]]; then
        echo "bun"
    else
        echo "npx"
    fi
}

run_tests() {
    local dir="${1:-.}"
    local framework
    framework=$(detect_test_framework "$dir")

    log_header "Running Tests" "🧪"
    log_info "Framework: $framework"

    case "$framework" in
        maven-surefire|maven)
            (cd "$dir" && mvn test -q)
            ;;
        gradle)
            if [[ -f "$dir/gradlew" ]]; then
                (cd "$dir" && ./gradlew test --quiet)
            else
                (cd "$dir" && gradle test --quiet)
            fi
            ;;
        vitest)
            local pm
            pm=$(detect_package_manager "$dir")
            (cd "$dir" && $pm vitest run --coverage 2>/dev/null || $pm vitest run)
            ;;
        jest)
            local pm
            pm=$(detect_package_manager "$dir")
            (cd "$dir" && $pm jest --coverage 2>/dev/null || $pm jest)
            ;;
        mocha)
            local pm
            pm=$(detect_package_manager "$dir")
            (cd "$dir" && $pm mocha)
            ;;
        npm-test)
            local pm
            pm=$(detect_package_manager "$dir")
            if [[ "$pm" == "npx" ]]; then
                (cd "$dir" && npm test)
            else
                (cd "$dir" && $pm test)
            fi
            ;;
        pytest)
            (cd "$dir" && python -m pytest --cov 2>/dev/null || python -m pytest)
            ;;
        go-test)
            (cd "$dir" && go test ./... -cover)
            ;;
        cargo-test)
            (cd "$dir" && cargo test)
            ;;
        *)
            log_error "Could not detect test framework"
            return 1
            ;;
    esac
}

main() {
    local dir="${1:-.}"
    run_tests "$dir"
}

main "$@"
