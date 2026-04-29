#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"

detect_project_type() {
    local dir="${1:-.}"

    if [[ -f "$dir/pom.xml" ]]; then
        echo "java-maven"
    elif [[ -f "$dir/build.gradle" ]] || [[ -f "$dir/build.gradle.kts" ]]; then
        echo "java-gradle"
    elif [[ -f "$dir/package.json" ]]; then
        if [[ -f "$dir/tsconfig.json" ]]; then
            echo "typescript-node"
        else
            echo "javascript-node"
        fi
    elif [[ -f "$dir/requirements.txt" ]] || [[ -f "$dir/pyproject.toml" ]] || [[ -f "$dir/setup.py" ]]; then
        echo "python"
    elif [[ -f "$dir/go.mod" ]]; then
        echo "go"
    elif [[ -f "$dir/Cargo.toml" ]]; then
        echo "rust"
    else
        echo "unknown"
    fi
}

detect_build_tool() {
    local project_type="$1"
    local dir="${2:-.}"

    case "$project_type" in
        java-maven) echo "mvn" ;;
        java-gradle)
            if [[ -f "$dir/gradlew" ]]; then
                echo "./gradlew"
            else
                echo "gradle"
            fi
            ;;
        typescript-node|javascript-node)
            if [[ -f "$dir/pnpm-lock.yaml" ]]; then
                echo "pnpm"
            elif [[ -f "$dir/yarn.lock" ]]; then
                echo "yarn"
            elif [[ -f "$dir/bun.lockb" ]]; then
                echo "bun"
            else
                echo "npm"
            fi
            ;;
        python)
            if [[ -f "$dir/pyproject.toml" ]]; then
                echo "poetry"
            else
                echo "pip"
            fi
            ;;
        go) echo "go" ;;
        rust) echo "cargo" ;;
        *) echo "unknown" ;;
    esac
}

list_key_files() {
    local dir="${1:-.}"
    local key_files=()

    local candidates=(
        "pom.xml" "build.gradle" "build.gradle.kts"
        "package.json" "tsconfig.json"
        "requirements.txt" "pyproject.toml" "setup.py"
        "go.mod" "Cargo.toml"
        "Dockerfile" "docker-compose.yml" "docker-compose.yaml"
        ".env" ".env.example"
        "Makefile"
        "README.md"
        ".github/workflows"
        "Jenkinsfile"
    )

    for candidate in "${candidates[@]}"; do
        if [[ -e "$dir/$candidate" ]]; then
            key_files+=("$candidate")
        fi
    done

    printf "%s\n" "${key_files[@]}"
}

main() {
    local dir="${1:-.}"

    log_header "Project Info"

    local project_type
    project_type=$(detect_project_type "$dir")
    log_info "Type: $project_type"

    local build_tool
    build_tool=$(detect_build_tool "$project_type" "$dir")
    log_info "Build tool: $build_tool"

    log_info "Key files:"
    list_key_files "$dir" | while IFS= read -r f; do
        echo "  - $f"
    done

    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
        local branch
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        log_info "Git branch: $branch"
    fi
}

main "$@"
