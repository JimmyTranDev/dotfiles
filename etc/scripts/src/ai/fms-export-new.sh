#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

show_help() {
	cat <<'EOF'
Usage: fms-export-new.sh [options] [directory]

Extract new/modified FMS keys from git diffs of fallback translation files.
Outputs JSON to stdout.

OPTIONS:
  --check-only    Report keys without generating fms.json
  -h, --help      Show this help message

ARGUMENTS:
  directory       Project directory (default: current directory)
EOF
}

generate_fms_export() {
	local dir="${1:-.}"
	local check_only="${2:-false}"
	local no_file="$dir/src/fms-fallbacks/fallback-no.json"
	local en_file="$dir/src/fms-fallbacks/fallback-en.json"

	if [[ ! -f "$no_file" ]] || [[ ! -f "$en_file" ]]; then
		log_error "FMS fallback files not found in $dir/src/fms-fallbacks/"
		exit 1
	fi

	local new_keys=""

	new_keys=$(git diff --cached --unified=0 -- "$no_file" "$en_file" 2>/dev/null |
		grep '^+' |
		grep -v '^+++' |
		sed -n 's/^+[[:space:]]*"\([^"]*\)":.*/\1/p' |
		sort -u)

	if [[ -z "$new_keys" ]]; then
		new_keys=$(git diff --unified=0 -- "$no_file" "$en_file" 2>/dev/null |
			grep '^+' |
			grep -v '^+++' |
			sed -n 's/^+[[:space:]]*"\([^"]*\)":.*/\1/p' |
			sort -u)
	fi

	if [[ -z "$new_keys" ]]; then
		new_keys=$(git diff HEAD~1 --unified=0 -- "$no_file" "$en_file" 2>/dev/null |
			grep '^+' |
			grep -v '^+++' |
			sed -n 's/^+[[:space:]]*"\([^"]*\)":.*/\1/p' |
			sort -u)
	fi

	if [[ -z "$new_keys" ]]; then
		log_warning "No new FMS keys found in git diff"
		json_output $(json_obj_raw \
			"keys_found" "0" \
			"new_keys" "[]" \
			"output_file" "$(json_escape "")" \
			"check_only" "$check_only")
		exit 0
	fi

	local count
	count=$(echo "$new_keys" | wc -l | tr -d ' ')

	local keys_json=""
	while IFS= read -r key; do
		if [[ -n "$key" ]]; then
			local escaped
			escaped=$(json_escape "$key")
			if [[ -n "$keys_json" ]]; then
				keys_json="${keys_json},${escaped}"
			else
				keys_json="$escaped"
			fi
		fi
	done <<<"$new_keys"

	local outfile=""
	if [[ "$check_only" != "true" ]]; then
		outfile="$dir/fms.json"

		python3 -c "
import json, sys

keys = sys.stdin.read().strip().split('\n')
no = json.load(open('$no_file'))
en = json.load(open('$en_file'))

result = [{'key': k, 'no': no.get(k, ''), 'en': en.get(k, '')} for k in keys]

with open('$outfile', 'w') as f:
    json.dump(result, f, indent=2, ensure_ascii=False)
    f.write('\n')
" <<<"$new_keys"

		log_success "Generated $outfile with $count new keys"
	else
		log_info "Check-only mode: found $count new FMS keys"
	fi

	json_output $(json_obj_raw \
		"keys_found" "$count" \
		"new_keys" "[${keys_json}]" \
		"output_file" "$(json_escape "$outfile")" \
		"check_only" "$check_only")
}

main() {
	local check_only=false
	local dir="."

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--check-only) check_only=true; shift ;;
		-h | --help) show_help; exit 0 ;;
		*) dir="$1"; shift ;;
		esac
	done

	generate_fms_export "$dir" "$check_only"
}

main "$@"
