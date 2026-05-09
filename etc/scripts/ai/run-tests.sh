#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"
source "$SCRIPT_DIR/../common/detect.sh"

run_tests() {
    local dir="${1:-.}"
    local framework
    framework=$(detect_test_runner "$dir")

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
            pm=$(detect_node_runner "$dir")
            (cd "$dir" && $pm vitest run --coverage 2>/dev/null || $pm vitest run)
            ;;
        jest)
            local pm
            pm=$(detect_node_runner "$dir")
            (cd "$dir" && $pm jest --coverage 2>/dev/null || $pm jest)
            ;;
        mocha)
            local pm
            pm=$(detect_node_runner "$dir")
            (cd "$dir" && $pm mocha)
            ;;
        npm-test)
            local pm
            pm=$(detect_node_runner "$dir")
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
