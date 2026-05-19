#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

run_linter() {
	local dir="${1:-.}"
	local fix="${2:-false}"
	local linter
	linter=$(detect_linter "$dir")

	log_header "Lint Check" "🔍"
	log_info "Linter: $linter"

	local cmd=""
	local exit_code=0

	case "$linter" in
	eslint)
		local pm
		pm=$(detect_node_runner "$dir")
		if [[ "$fix" == "true" ]]; then
			cmd="$pm eslint . --fix"
		else
			cmd="$pm eslint ."
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	biome)
		local pm
		pm=$(detect_node_runner "$dir")
		if [[ "$fix" == "true" ]]; then
			cmd="$pm biome check --write ."
		else
			cmd="$pm biome check ."
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	ruff)
		if [[ "$fix" == "true" ]]; then
			cmd="ruff check --fix ."
		else
			cmd="ruff check ."
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	golangci-lint)
		if [[ "$fix" == "true" ]]; then
			cmd="golangci-lint run --fix ./..."
		else
			cmd="golangci-lint run ./..."
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	clippy)
		if [[ "$fix" == "true" ]]; then
			cmd="cargo clippy --fix --allow-dirty"
		else
			cmd="cargo clippy"
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	checkstyle-maven)
		cmd="mvn checkstyle:check -q"
		(cd "$dir" && mvn checkstyle:check -q) || exit_code=$?
		;;
	checkstyle-gradle)
		local gradle_cmd="gradle"
		if [[ -f "$dir/gradlew" ]]; then
			gradle_cmd="./gradlew"
		fi
		cmd="$gradle_cmd checkstyleMain --quiet"
		(cd "$dir" && $gradle_cmd checkstyleMain --quiet) || exit_code=$?
		;;
	*)
		log_error "Could not detect linter"
		return 1
		;;
	esac

	json_output "$(json_obj_raw \
		"linter" "$(json_escape "$linter")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"fix" "$fix")"
}

show_help() {
	cat <<'EOF' >&2
Usage: lint-check.sh [OPTIONS] [directory]

Auto-detect linter and run lint check.

Options:
  --fix     Auto-fix issues where supported
  --help    Show this help message
EOF
}

main() {
	local dir="."
	local fix="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--fix)
			fix="true"
			shift
			;;
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

	run_linter "$dir" "$fix"
}

main "$@"
