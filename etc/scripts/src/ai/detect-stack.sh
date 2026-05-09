#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/logging.sh"
source "$SCRIPT_DIR/../../lib/detect.sh"

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

detect_ci() {
    local dir="${1:-.}"

    if [[ -d "$dir/.github/workflows" ]]; then
        echo "github-actions"
    elif [[ -f "$dir/.gitlab-ci.yml" ]]; then
        echo "gitlab-ci"
    elif [[ -f "$dir/Jenkinsfile" ]]; then
        echo "jenkins"
    elif [[ -f "$dir/.circleci/config.yml" ]]; then
        echo "circleci"
    elif [[ -f "$dir/bitbucket-pipelines.yml" ]]; then
        echo "bitbucket"
    elif [[ -f "$dir/azure-pipelines.yml" ]]; then
        echo "azure-devops"
    else
        echo "none"
    fi
}

detect_framework() {
    local dir="${1:-.}"

    if [[ -f "$dir/package.json" ]]; then
        local pkg="$dir/package.json"
        if grep -q '"next"' "$pkg" 2>/dev/null; then
            echo "nextjs"
        elif grep -q '"expo"' "$pkg" 2>/dev/null; then
            echo "expo"
        elif grep -q '"react-native"' "$pkg" 2>/dev/null; then
            echo "react-native"
        elif grep -q '"react"' "$pkg" 2>/dev/null; then
            echo "react"
        elif grep -q '"vue"' "$pkg" 2>/dev/null; then
            echo "vue"
        elif grep -q '"svelte"' "$pkg" 2>/dev/null; then
            echo "svelte"
        elif grep -q '"angular"' "$pkg" 2>/dev/null; then
            echo "angular"
        elif grep -q '"express"' "$pkg" 2>/dev/null; then
            echo "express"
        elif grep -q '"fastify"' "$pkg" 2>/dev/null; then
            echo "fastify"
        elif grep -q '"hono"' "$pkg" 2>/dev/null; then
            echo "hono"
        else
            echo "none"
        fi
    elif [[ -f "$dir/pom.xml" ]] && grep -q "spring-boot" "$dir/pom.xml" 2>/dev/null; then
        echo "spring-boot"
    elif [[ -f "$dir/build.gradle" ]] && grep -q "spring-boot" "$dir/build.gradle" 2>/dev/null; then
        echo "spring-boot"
    elif [[ -f "$dir/build.gradle.kts" ]] && grep -q "spring-boot" "$dir/build.gradle.kts" 2>/dev/null; then
        echo "spring-boot"
    else
        echo "none"
    fi
}

detect_monorepo() {
    local dir="${1:-.}"

    if [[ -f "$dir/turbo.json" ]]; then
        echo "turborepo"
    elif [[ -f "$dir/nx.json" ]]; then
        echo "nx"
    elif [[ -f "$dir/lerna.json" ]]; then
        echo "lerna"
    elif [[ -f "$dir/pnpm-workspace.yaml" ]]; then
        echo "pnpm-workspaces"
    elif [[ -f "$dir/package.json" ]] && grep -q '"workspaces"' "$dir/package.json" 2>/dev/null; then
        echo "npm-workspaces"
    else
        echo "none"
    fi
}

detect_css_framework() {
    local dir="${1:-.}"

    if [[ -f "$dir/tailwind.config.js" ]] || [[ -f "$dir/tailwind.config.ts" ]] || [[ -f "$dir/tailwind.config.mjs" ]]; then
        echo "tailwind"
    elif [[ -f "$dir/package.json" ]] && grep -q '"styled-components"' "$dir/package.json" 2>/dev/null; then
        echo "styled-components"
    elif [[ -f "$dir/package.json" ]] && grep -q '"@emotion"' "$dir/package.json" 2>/dev/null; then
        echo "emotion"
    else
        echo "none"
    fi
}

detect_database() {
    local dir="${1:-.}"

    local dbs=""
    for compose_file in docker-compose.yml docker-compose.yaml compose.yml compose.yaml; do
        if [[ -f "$dir/$compose_file" ]]; then
            if grep -q "postgres" "$dir/$compose_file" 2>/dev/null; then
                dbs="postgresql"
            elif grep -q "mysql" "$dir/$compose_file" 2>/dev/null; then
                dbs="mysql"
            elif grep -q "mongo" "$dir/$compose_file" 2>/dev/null; then
                dbs="mongodb"
            elif grep -q "redis" "$dir/$compose_file" 2>/dev/null; then
                dbs="${dbs:+$dbs,}redis"
            fi
            break
        fi
    done

    if [[ -f "$dir/package.json" ]]; then
        if grep -q '"prisma"' "$dir/package.json" 2>/dev/null; then
            dbs="${dbs:+$dbs,}prisma"
        elif grep -q '"drizzle-orm"' "$dir/package.json" 2>/dev/null; then
            dbs="${dbs:+$dbs,}drizzle"
        fi
    fi

    if [[ -z "$dbs" ]]; then
        echo "none"
    else
        echo "$dbs"
    fi
}

list_key_files() {
    local dir="${1:-.}"

    local candidates=(
        "pom.xml" "build.gradle" "build.gradle.kts"
        "package.json" "tsconfig.json"
        "requirements.txt" "pyproject.toml" "setup.py"
        "go.mod" "Cargo.toml"
        "Dockerfile" "docker-compose.yml" "docker-compose.yaml"
        ".env" ".env.example"
        "Makefile"
        ".github/workflows"
        "Jenkinsfile"
    )

    local found=()
    for candidate in "${candidates[@]}"; do
        if [[ -e "$dir/$candidate" ]]; then
            found+=("$candidate")
        fi
    done

    printf "%s," "${found[@]}" | sed 's/,$//'
}

show_help() {
    echo "Usage: detect-stack.sh [directory]"
    echo ""
    echo "Full tech stack detection. Outputs KEY=VALUE pairs."
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

    echo "PROJECT_TYPE=$(detect_project_type "$dir")"
    echo "PACKAGE_MANAGER=$(detect_package_manager "$dir")"
    echo "TEST_RUNNER=$(detect_test_runner "$dir")"
    echo "LINTER=$(detect_linter "$dir")"
    echo "CI=$(detect_ci "$dir")"
    echo "FRAMEWORK=$(detect_framework "$dir")"
    echo "MONOREPO=$(detect_monorepo "$dir")"
    echo "CSS_FRAMEWORK=$(detect_css_framework "$dir")"
    echo "DATABASE=$(detect_database "$dir")"
    echo "KEY_FILES=$(list_key_files "$dir")"

    if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
        local branch
        branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
        echo "GIT_BRANCH=$branch"
    fi
}

main "$@"
