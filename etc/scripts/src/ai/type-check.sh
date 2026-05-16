#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/json.sh"
source "$SCRIPT_DIR/../../utils/detect.sh"

run_type_checker() {
	local dir="$1"
	local checker
	checker=$(detect_type_checker "$dir")

	if [[ "$checker" == "none" ]]; then
		log_error "Could not detect type checker in: $dir"
		json_output "$(json_obj_raw \
			"type_checker" "$(json_escape "none")" \
			"command" "$(json_escape "")" \
			"exit_code" "1" \
			"error_count" "0" \
			"errors" "[]")"
		return 0
	fi

	log_info "Type checker: $checker"

	local cmd=""
	local pm

	case "$checker" in
	tsc)
		pm=$(detect_node_runner "$dir")
		cmd="$pm tsc --noEmit"
		;;
	mypy)
		cmd="mypy ."
		;;
	cargo-check)
		cmd="cargo check"
		;;
	*)
		log_error "Unknown type checker: $checker"
		json_output "$(json_obj_raw \
			"type_checker" "$(json_escape "$checker")" \
			"command" "$(json_escape "")" \
			"exit_code" "1" \
			"error_count" "0" \
			"errors" "[]")"
		return 0
		;;
	esac

	log_info "Running: $cmd"

	local output=""
	local exit_code=0
	output=$( (cd "$dir" && eval "$cmd") 2>&1) || exit_code=$?

	local errors_json="[]"
	local error_count=0

	if [[ $exit_code -ne 0 ]] && [[ -n "$output" ]]; then
		case "$checker" in
		tsc)
			errors_json=$(echo "$output" | grep -E '^.+\([0-9]+,[0-9]+\): error' | head -50 | while IFS= read -r line; do
				local file
				file=$(echo "$line" | sed -E 's/\([0-9]+,[0-9]+\): error.*//' | sed 's/ *$//')
				local line_num
				line_num=$(echo "$line" | sed -E 's/.*\(([0-9]+),[0-9]+\).*/\1/')
				local message
				message=$(echo "$line" | sed -E 's/.*\([0-9]+,[0-9]+\): error [A-Z0-9]+: //')
				json_obj "file" "$file" "line" "$line_num" "message" "$message"
			done | jq -sc '.')
			error_count=$(echo "$output" | grep -cE '^.+\([0-9]+,[0-9]+\): error' || echo "0")
			;;
		mypy)
			errors_json=$(echo "$output" | grep -E '^.+:[0-9]+: error:' | head -50 | while IFS= read -r line; do
				local file
				file=$(echo "$line" | cut -d: -f1)
				local line_num
				line_num=$(echo "$line" | cut -d: -f2)
				local message
				message=$(echo "$line" | sed -E 's/^.+:[0-9]+: error: //')
				json_obj "file" "$file" "line" "$line_num" "message" "$message"
			done | jq -sc '.')
			error_count=$(echo "$output" | grep -cE '^.+:[0-9]+: error:' || echo "0")
			;;
		cargo-check)
			error_count=$(echo "$output" | grep -c '^error' || echo "0")
			errors_json="[]"
			;;
		esac
	fi

	if [[ -n "$output" ]]; then
		log_info "$output"
	fi

	json_output "$(json_obj_raw \
		"type_checker" "$(json_escape "$checker")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$exit_code" \
		"error_count" "$error_count" \
		"errors" "$errors_json")"
}

show_help() {
	echo "Usage: type-check.sh [directory]" >&2
	echo "" >&2
	echo "Auto-detect and run type checker." >&2
	echo "" >&2
	echo "Options:" >&2
	echo "  --help    Show this help message" >&2
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

	run_type_checker "$dir"
}

main "$@"
