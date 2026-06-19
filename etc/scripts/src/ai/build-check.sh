#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

run_build() {
	local dir="$1"
	local build_spec
	build_spec=$(detect_build_command "$dir")

	if [[ "$build_spec" == "none" ]]; then
		log_error "Could not detect build command in: $dir"
		json_output "$(json_obj_raw \
			"build_tool" "$(json_escape "none")" \
			"command" "$(json_escape "")" \
			"exit_code" "1" \
			"duration_seconds" "0")"
		return 0
	fi

	local tool="${build_spec%%:*}"
	local task="${build_spec#*:}"

	log_info "Build tool: $tool, task: $task"

	local cmd=""

	case "$tool" in
	npx | pnpm | yarn | bun)
		if [[ "$tool" == "npx" ]]; then
			cmd="npm run $task"
		else
			cmd="$tool run $task"
		fi
		;;
	mvn)
		cmd="mvn $task -q"
		;;
	./gradlew)
		cmd="./gradlew $task --quiet"
		;;
	gradle)
		cmd="gradle $task --quiet"
		;;
	cargo)
		cmd="cargo $task"
		;;
	go)
		cmd="go $task ./..."
		;;
	*)
		log_error "Unknown build tool: $tool"
		json_output "$(json_obj_raw \
			"build_tool" "$(json_escape "$tool")" \
			"command" "$(json_escape "")" \
			"exit_code" "1" \
			"duration_seconds" "0")"
		return 0
		;;
	esac

	log_info "Running: $cmd"

	run_capture_exit "$dir" "$cmd"

	json_output "$(json_obj_raw \
		"build_tool" "$(json_escape "$tool")" \
		"command" "$(json_escape "$cmd")" \
		"exit_code" "$RUN_EXIT_CODE" \
		"duration_seconds" "$RUN_DURATION")"
}

show_help() {
	echo "Usage: build-check.sh [directory]" >&2
	echo "" >&2
	echo "Auto-detect and run build." >&2
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

	run_build "$dir"
}

main "$@"
