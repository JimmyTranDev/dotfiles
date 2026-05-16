#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

run_tests() {
	local dir="${1:-.}"
	local framework
	framework=$(detect_test_runner "$dir")

	log_header "Running Tests" "🧪"
	log_info "Framework: $framework"

	local cmd=""
	local exit_code=0

	case "$framework" in
	maven-surefire | maven)
		cmd="mvn test -q"
		(cd "$dir" && mvn test -q) || exit_code=$?
		;;
	gradle)
		if [[ -f "$dir/gradlew" ]]; then
			cmd="./gradlew test --quiet"
		else
			cmd="gradle test --quiet"
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	vitest)
		local pm
		pm=$(detect_node_runner "$dir")
		cmd="$pm vitest run --coverage"
		(cd "$dir" && $pm vitest run --coverage 2>/dev/null || $pm vitest run) || exit_code=$?
		;;
	jest)
		local pm
		pm=$(detect_node_runner "$dir")
		cmd="$pm jest --coverage"
		(cd "$dir" && $pm jest --coverage 2>/dev/null || $pm jest) || exit_code=$?
		;;
	mocha)
		local pm
		pm=$(detect_node_runner "$dir")
		cmd="$pm mocha"
		(cd "$dir" && $pm mocha) || exit_code=$?
		;;
	npm-test)
		local pm
		pm=$(detect_node_runner "$dir")
		if [[ "$pm" == "npx" ]]; then
			cmd="npm test"
		else
			cmd="$pm test"
		fi
		(cd "$dir" && eval "$cmd") || exit_code=$?
		;;
	pytest)
		cmd="python -m pytest --cov"
		(cd "$dir" && python -m pytest --cov 2>/dev/null || python -m pytest) || exit_code=$?
		;;
	go-test)
		cmd="go test ./... -cover"
		(cd "$dir" && go test ./... -cover) || exit_code=$?
		;;
	cargo-test)
		cmd="cargo test"
		(cd "$dir" && cargo test) || exit_code=$?
		;;
	*)
		log_error "Could not detect test framework"
		return 1
		;;
	esac

	json_output "$(json_obj_raw \
		"test_runner" "$(json_escape "$framework")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code")"
}

main() {
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			log_info "Usage: run-tests.sh [directory]"
			log_info ""
			log_info "Auto-detect test framework and run tests."
			exit 0
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	run_tests "$dir"
}

main "$@"
