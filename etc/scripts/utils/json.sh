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

# Run a tool command in a directory, capture output and exit code, emit JSON
# Usage: run_tool_json <tool_key> <tool_name> <cmd> <dir> [extra_key extra_val ...]
# Example: run_tool_json "linter" "eslint" "npx eslint ." "/path"
# Output: {"<tool_key>":"<tool_name>","command":"<cmd>","exit_code":0}
run_tool_json() {
	local tool_key="$1"
	local tool_name="$2"
	local cmd="$3"
	local dir="$4"
	shift 4

	local exit_code=0
	local output=""
	SECONDS=0
	output=$( (cd "$dir" && eval "$cmd") 2>&1) || exit_code=$?
	local duration=$SECONDS

	if [[ -n "$output" ]]; then
		echo "$output" >&2
	fi

	local -a args=(
		"$tool_key" "$(json_escape "$tool_name")"
		"command" "$(json_escape "$cmd")"
		"exit_code" "$exit_code"
	)

	while [[ $# -ge 2 ]]; do
		args+=("$1" "$2")
		shift 2
	done

	json_output "$(json_obj_raw "${args[@]}")"
}
