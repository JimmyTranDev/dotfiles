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
