#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

run_formatter() {
	local dir="$1"
	local fix="$2"
	local formatter
	formatter=$(detect_formatter "$dir")

	if [[ "$formatter" == "none" ]]; then
		log_error "Could not detect formatter in: $dir"
		json_output "$(json_obj_raw \
			"formatter" "$(json_escape "none")" \
			"command" "$(json_escape "")" \
			"exit_code" "1")"
		return 0
	fi

	log_info "Formatter: $formatter"

	local cmd=""
	local pm

	case "$formatter" in
	prettier)
		pm=$(detect_node_runner "$dir")
		if [[ "$fix" == "true" ]]; then
			cmd="$pm prettier --write ."
		else
			cmd="$pm prettier --check ."
		fi
		;;
	biome)
		pm=$(detect_node_runner "$dir")
		if [[ "$fix" == "true" ]]; then
			cmd="$pm biome format --write ."
		else
			cmd="$pm biome format --check ."
		fi
		;;
	black)
		if [[ "$fix" == "true" ]]; then
			cmd="black ."
		else
			cmd="black --check ."
		fi
		;;
	gofmt)
		if [[ "$fix" == "true" ]]; then
			cmd="gofmt -w ."
		else
			cmd="gofmt -l ."
		fi
		;;
	rustfmt)
		if [[ "$fix" == "true" ]]; then
			cmd="cargo fmt"
		else
			cmd="cargo fmt -- --check"
		fi
		;;
	*)
		log_error "Unknown formatter: $formatter"
		json_output "$(json_obj_raw \
			"formatter" "$(json_escape "$formatter")" \
			"command" "$(json_escape "")" \
			"exit_code" "1")"
		return 0
		;;
	esac

	log_info "Running: $cmd"

	run_capture_exit "$dir" "$cmd"

	json_output "$(json_obj_raw \
		"formatter" "$(json_escape "$formatter")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$RUN_EXIT_CODE")"
}

show_help() {
	echo "Usage: format-check.sh [--fix] [directory]" >&2
	echo "" >&2
	echo "Auto-detect and run formatter." >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --fix     Run in fix mode instead of check mode" >&2
	echo "  --help    Show this help message" >&2
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

	run_formatter "$dir" "$fix"
}

main "$@"
