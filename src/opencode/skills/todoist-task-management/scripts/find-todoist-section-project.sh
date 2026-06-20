#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../../etc/scripts/utils/common.sh"

extract_section_id() {
	local ref="$1"
	local section_id
	# Accepts a section URL (.../section/name-ID), an id:xxx ref, or a raw ID.
	# The ID is always the trailing alphanumeric run.
	section_id=$(echo "$ref" | grep -oE '[A-Za-z0-9]+$' || echo "")
	if [[ -z "$section_id" ]]; then
		log_error "Could not extract section ID from: $ref"
		return 1
	fi
	echo "$section_id"
}

find_project_for_section() {
	local section_id="$1"
	local projects_json
	projects_json=$(td project list --json 2>/dev/null)

	while IFS= read -r proj; do
		[[ -z "$proj" ]] && continue
		local pid pname
		pid=$(echo "$proj" | jq -r '.id')
		pname=$(echo "$proj" | jq -r '.name')
		local sections
		sections=$(td section list "$pname" --json 2>/dev/null || echo '{"results":[]}')
		if echo "$sections" | jq -e --arg s "$section_id" '.results[] | select(.id == $s)' &>/dev/null; then
			# project found; emit "id<TAB>name"
			printf '%s\t%s\n' "$pid" "$pname"
			return 0
		fi
	done < <(echo "$projects_json" | jq -c '.results[]' 2>/dev/null)

	return 1
}

resolve() {
	local section_ref="$1"

	local section_id
	section_id=$(extract_section_id "$section_ref")

	log_info "Resolving project for section $section_id" >&2

	local found project_id project_name
	if ! found=$(find_project_for_section "$section_id"); then
		log_error "Could not find a project containing section: $section_id"
		return 1
	fi
	project_id="${found%%$'\t'*}"
	project_name="${found#*$'\t'}"

	local result
	result=$(json_obj_raw \
		"section_id" "$(json_escape "$section_id")" \
		"project_id" "$(json_escape "$project_id")" \
		"project_name" "$(json_escape "$project_name")")
	json_output "$result"
}

show_help() {
	echo "Usage: find-todoist-section-project.sh <section-url|id:xxx|section-id>"
	echo ""
	echo "Find which Todoist project owns a section, by iterating projects."
	echo "Todoist has no direct section->project lookup, and 'td view' rejects"
	echo "section URLs, so this resolves it via 'td section list' per project."
	echo ""
	echo "Outputs JSON: {section_id, project_id, project_name}"
	echo ""
	echo "Options:"
	echo "  --help, -h   Show this help message"
}

main() {
	local section_ref=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		*)
			if [[ -z "$section_ref" ]]; then
				section_ref="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "$section_ref" ]]; then
		log_error "A section URL, id:xxx ref, or section ID is required"
		show_help >&2
		return 1
	fi

	require_command "td" "pnpm add -g @doist/todoist-cli"
	require_command "jq" "brew install jq"
	resolve "$section_ref"
}

main "$@"
