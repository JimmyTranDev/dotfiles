#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

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

	echo "${found[@]}"
}

show_help() {
	cat <<'EOF' >&2
Usage: detect-stack.sh [directory]

Full tech stack detection. Outputs JSON to stdout.

Options:
  --help    Show this help message
EOF
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

	local project_type package_manager test_runner linter ci framework monorepo css_framework database
	project_type=$(detect_project_type "$dir")
	package_manager=$(detect_project_package_manager "$dir")
	test_runner=$(detect_test_runner "$dir")
	linter=$(detect_linter "$dir")
	ci=$(detect_ci "$dir")
	framework=$(detect_framework "$dir")
	monorepo=$(detect_monorepo "$dir")
	css_framework=$(detect_css_framework "$dir")
	database=$(detect_database "$dir")

	local key_files_raw=()
	while IFS= read -r kf; do
		[[ -n "$kf" ]] && key_files_raw+=("$kf")
	done < <(list_key_files "$dir" | tr ' ' '\n')
	local key_files_json
	key_files_json=$(json_arr "${key_files_raw[@]}")

	local git_branch="null"
	if [[ -d "$dir/.git" ]] || [[ -f "$dir/.git" ]]; then
		git_branch=$(json_escape "$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")")
	fi

	json_output "$(json_obj_raw \
		"project_type" "$(json_escape "$project_type")" \
		"package_manager" "$(json_escape "$package_manager")" \
		"test_runner" "$(json_escape "$test_runner")" \
		"linter" "$(json_escape "$linter")" \
		"ci" "$(json_escape "$ci")" \
		"framework" "$(json_escape "$framework")" \
		"monorepo" "$(json_escape "$monorepo")" \
		"css_framework" "$(json_escape "$css_framework")" \
		"database" "$(json_escape "$database")" \
		"key_files" "$key_files_json" \
		"git_branch" "$git_branch")"
}

main "$@"
