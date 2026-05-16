#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

get_last_tag() {
	git describe --tags --abbrev=0 2>/dev/null || echo ""
}

generate_changelog() {
	local from_ref="$1"
	local to_ref="${2:-HEAD}"

	if [[ -z "$from_ref" ]]; then
		from_ref=$(get_last_tag)
	fi

	local range
	if [[ -n "$from_ref" ]]; then
		range="${from_ref}..${to_ref}"
		log_info "Generating changelog: $range"
	else
		range="$to_ref"
		log_info "Generating changelog: all commits to $to_ref"
	fi

	local commits
	commits=$(git log "$range" --pretty=format:"%s" --no-merges 2>/dev/null || echo "")

	local from_display="${from_ref:-}"

	if [[ -z "$commits" ]]; then
		json_output "{\"from\":$(json_escape "$from_display"),\"to\":$(json_escape "$to_ref"),\"entries\":[]}"
		return 0
	fi

	# Use jq to safely build JSON from commit messages
	echo "$commits" | jq -R '{
		type: (
			if startswith("feat") then "feat"
			elif startswith("fix") then "fix"
			elif startswith("chore") then "chore"
			elif startswith("refactor") then "refactor"
			elif startswith("docs") then "docs"
			elif startswith("test") then "test"
			elif startswith("perf") then "perf"
			else "other"
			end
		),
		message: .
	}' | jq -sc --arg from "$from_display" --arg to "$to_ref" '{from: $from, to: $to, entries: .}'
}

show_help() {
	echo "Usage: changelog.sh [from-ref] [to-ref]"
	echo ""
	echo "Generate grouped changelog from git history as JSON."
	echo "Defaults: from last tag to HEAD."
	echo ""
	echo "Options:"
	echo "  --help    Show this help message"
}

main() {
	local from_ref=""
	local to_ref="HEAD"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		*)
			if [[ -z "$from_ref" ]]; then
				from_ref="$1"
			else
				to_ref="$1"
			fi
			shift
			;;
		esac
	done

	generate_changelog "$from_ref" "$to_ref"
}

main "$@"
