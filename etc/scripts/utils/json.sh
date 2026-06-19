#!/bin/bash

[[ -n "${_UTILS_JSON_LOADED:-}" ]] && return 0
_UTILS_JSON_LOADED=1

# Escape a string for safe JSON embedding using jq
# Usage: json_escape "some string with \"quotes\" and newlines"
json_escape() {
	if [[ -z "$1" ]]; then
		printf '""'
	else
		printf '%s' "$1" | jq -Rc .
	fi
}

# Build a JSON object from key=value pairs
# Usage: json_obj "key1" "value1" "key2" "value2"
# Output: {"key1":"value1","key2":"value2"}
json_obj() {
	local result="{"
	local first=true
	while [[ $# -ge 2 ]]; do
		if [[ "$first" == "true" ]]; then
			first=false
		else
			result+=","
		fi
		result+="$(json_escape "$1"):$(json_escape "$2")"
		shift 2
	done
	result+="}"
	printf '%s' "$result"
}

# Build a JSON object with mixed types (strings, raw JSON values)
# Usage: json_obj_raw "key1" "\"string_val\"" "key2" "42" "key3" "[1,2,3]"
# Output: {"key1":"string_val","key2":42,"key3":[1,2,3]}
json_obj_raw() {
	local result="{"
	local first=true
	while [[ $# -ge 2 ]]; do
		if [[ "$first" == "true" ]]; then
			first=false
		else
			result+=","
		fi
		result+="$(json_escape "$1"):$2"
		shift 2
	done
	result+="}"
	printf '%s' "$result"
}

# Build a JSON array from values
# Usage: json_arr "val1" "val2" "val3"
# Output: ["val1","val2","val3"]
json_arr() {
	local result="["
	local first=true
	for val in "$@"; do
		if [[ "$first" == "true" ]]; then
			first=false
		else
			result+=","
		fi
		result+="$(json_escape "$val")"
		shift
	done
	result+="]"
	printf '%s' "$result"
}

# Build a JSON array from raw values (no escaping)
# Usage: json_arr_raw '{"a":1}' '{"b":2}'
# Output: [{"a":1},{"b":2}]
json_arr_raw() {
	local result="["
	local first=true
	for val in "$@"; do
		if [[ "$first" == "true" ]]; then
			first=false
		else
			result+=","
		fi
		result+="$val"
	done
	result+="]"
	printf '%s' "$result"
}

# Output minified JSON to stdout (just a pass-through for clarity)
# Usage: json_output '{"key":"value"}'
json_output() {
	printf '%s\n' "$1"
}

# Run a command in a directory; capture its exit code and elapsed seconds.
# Streams the command's stdout+stderr live to the script's stderr via the
# `>&2 2>&1` idiom, keeping the script's stdout clean for the JSON line.
# Does NOT emit JSON or dictate output keys — callers build their own JSON
# from the result globals.
# Sets globals: RUN_EXIT_CODE (int), RUN_DURATION (whole seconds).
# Usage: run_capture_exit <dir> <cmd>
run_capture_exit() {
	local dir="$1"
	local cmd="$2"

	RUN_EXIT_CODE=0
	SECONDS=0
	(cd "$dir" && eval "$cmd") >&2 2>&1 || RUN_EXIT_CODE=$?
	RUN_DURATION=$SECONDS
}
