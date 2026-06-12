#!/bin/bash
# Intentionally no set -e: individual check scripts may fail and we must continue

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

GRAY='\033[0;90m'

CHECK_NAMES=("build" "type" "lint" "format" "test")
CHECK_SCRIPTS=("build-check.sh" "type-check.sh" "lint-check.sh" "format-check.sh" "run-tests.sh")

run_single_check() {
	local name="$1"
	local script_file="$2"
	local dir="$3"
	local script_path="$SCRIPT_DIR/$script_file"

	_CHECK_STATUS="skipped"
	_CHECK_EXIT_CODE=0
	_CHECK_DURATION=0

	if [[ ! -f "$script_path" ]]; then
		return
	fi

	local output=""
	local exit_code=0
	SECONDS=0
	output=$(bash "$script_path" "$dir" 2>/dev/null) || exit_code=$?
	_CHECK_DURATION=$SECONDS

	if [[ -z "$output" ]]; then
		_CHECK_EXIT_CODE=$exit_code
		if [[ $exit_code -eq 0 ]]; then
			_CHECK_STATUS="pass"
		else
			_CHECK_STATUS="fail"
		fi
		return
	fi

	local last_line
	last_line=$(echo "$output" | grep -v '^$' | tail -1)

	local json_exit_code
	json_exit_code=$(echo "$last_line" | jq -r '.exit_code // empty' 2>/dev/null)

	if [[ -z "$json_exit_code" ]]; then
		_CHECK_EXIT_CODE=$exit_code
		if [[ $exit_code -eq 0 ]]; then
			_CHECK_STATUS="pass"
		else
			_CHECK_STATUS="fail"
		fi
		return
	fi

	_CHECK_EXIT_CODE=$json_exit_code

	local has_none
	has_none=$(echo "$last_line" | jq -r 'to_entries[] | select(.value == "none") | .key' 2>/dev/null)

	if [[ -n "$has_none" ]]; then
		return
	fi

	if [[ "$json_exit_code" -eq 0 ]]; then
		_CHECK_STATUS="pass"
	else
		_CHECK_STATUS="fail"
	fi
}

run_checks() {
	local dir="$1"
	shift
	local -a skip_list=("$@")

	local -a result_entries=()
	local failed_count=0
	local skipped_count=0
	local total_start
	total_start=$(date +%s)

	for i in "${!CHECK_NAMES[@]}"; do
		local name="${CHECK_NAMES[$i]}"
		local script="${CHECK_SCRIPTS[$i]}"

		local should_skip=false
		for skip in "${skip_list[@]}"; do
			if [[ "$skip" == "$name" ]]; then
				should_skip=true
				break
			fi
		done

		if [[ "$should_skip" == "true" ]]; then
			result_entries+=("$(json_obj_raw \
				"name" "$(json_escape "$name")" \
				"status" "$(json_escape "skipped")" \
				"exit_code" "0" \
				"duration_seconds" "0")")
			skipped_count=$((skipped_count + 1))
			continue
		fi

		log_info "Running $name check..."
		run_single_check "$name" "$script" "$dir"

		result_entries+=("$(json_obj_raw \
			"name" "$(json_escape "$name")" \
			"status" "$(json_escape "$_CHECK_STATUS")" \
			"exit_code" "$_CHECK_EXIT_CODE" \
			"duration_seconds" "$_CHECK_DURATION")")

		if [[ "$_CHECK_STATUS" == "fail" ]]; then
			failed_count=$((failed_count + 1))
		elif [[ "$_CHECK_STATUS" == "skipped" ]]; then
			skipped_count=$((skipped_count + 1))
		fi
	done

	local total_end
	total_end=$(date +%s)
	local total_duration=$((total_end - total_start))

	local all_passed="true"
	if [[ $failed_count -gt 0 ]]; then
		all_passed="false"
	fi

	echo "" >&2
	log_header "Verification Summary"
	for entry in "${result_entries[@]}"; do
		local entry_name
		entry_name=$(echo "$entry" | jq -r '.name')
		local entry_status
		entry_status=$(echo "$entry" | jq -r '.status')
		local entry_duration
		entry_duration=$(echo "$entry" | jq -r '.duration_seconds')

		case "$entry_status" in
		pass)
			echo -e "  ${GREEN}${EMOJI_SUCCESS} $entry_name${NC} (${entry_duration}s)" >&2
			;;
		fail)
			echo -e "  ${RED}${EMOJI_ERROR} $entry_name${NC} (${entry_duration}s)" >&2
			;;
		skipped)
			echo -e "  ${GRAY}- $entry_name${NC} (skipped)" >&2
			;;
		esac
	done
	echo -e "\n  Total: ${total_duration}s" >&2

	local checks_json
	checks_json=$(json_arr_raw "${result_entries[@]}")

	json_output "$(json_obj_raw \
		"checks" "$checks_json" \
		"all_passed" "$all_passed" \
		"failed_count" "$failed_count" \
		"skipped_count" "$skipped_count" \
		"total_duration_seconds" "$total_duration")"

	if [[ $failed_count -gt 0 ]]; then
		return 1
	fi
	return 0
}

show_help() {
	cat <<'EOF' >&2
Usage: verify-all.sh [OPTIONS] [directory]

Run all verification checks and return aggregate results.

Checks: build, type, lint, format, test

Options:
  --skip <check>  Skip a specific check (can be repeated)
  --help          Show this help message
EOF
}

main() {
	local dir="."
	local -a skip_checks=()

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--skip)
			if [[ $# -lt 2 ]]; then
				log_error "--skip requires a check name"
				show_help
				exit 1
			fi
			skip_checks+=("$2")
			shift 2
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

	run_checks "$dir" "${skip_checks[@]}"
}

main "$@"
