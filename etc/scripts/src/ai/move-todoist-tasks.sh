#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

extract_section_id() {
	local url="$1"
	local section_id
	# Todoist section URLs: .../section/name-ID where ID is alphanumeric
	section_id=$(echo "$url" | grep -oE '[A-Za-z0-9]+$' || echo "")
	if [[ -z "$section_id" ]]; then
		log_error "Could not extract section ID from URL: $url"
		return 1
	fi
	echo "$section_id"
}

find_project_for_section() {
	local section_id="$1"
	local projects_json
	projects_json=$(td project list --json 2>/dev/null)

	local project_id=""
	while IFS= read -r proj; do
		[[ -z "$proj" ]] && continue
		local pid pname
		pid=$(echo "$proj" | jq -r '.id')
		pname=$(echo "$proj" | jq -r '.name')
		local sections
		sections=$(td section list "$pname" --json 2>/dev/null || echo '{"results":[]}')
		if echo "$sections" | jq -e ".results[] | select(.id == \"$section_id\")" &>/dev/null; then
			project_id="$pid"
			break
		fi
	done < <(echo "$projects_json" | jq -c '.results[]' 2>/dev/null)

	if [[ -z "$project_id" ]]; then
		log_error "Could not find project containing section: $section_id"
		return 1
	fi
	echo "$project_id"
}

move_tasks() {
	local source_url="$1"
	local dest_url="$2"

	local source_section_id dest_section_id
	source_section_id=$(extract_section_id "$source_url")
	dest_section_id=$(extract_section_id "$dest_url")

	log_info "Source section ID: $source_section_id" >&2
	log_info "Dest section ID: $dest_section_id" >&2

	# Find which project contains the source section
	log_info "Finding project for source section..." >&2
	local project_id
	project_id=$(find_project_for_section "$source_section_id")
	log_info "Project ID: $project_id" >&2

	# Get all tasks in the project and filter by source section
	local tasks_json
	tasks_json=$(td task list --project "id:$project_id" --json --full --all 2>/dev/null)

	local task_ids=()
	local task_names=()
	while IFS= read -r task; do
		[[ -z "$task" ]] && continue
		local tid tcontent tsection
		tid=$(echo "$task" | jq -r '.id')
		tcontent=$(echo "$task" | jq -r '.content')
		tsection=$(echo "$task" | jq -r '.sectionId // empty')
		if [[ "$tsection" == "$source_section_id" ]]; then
			task_ids+=("$tid")
			task_names+=("$tcontent")
		fi
	done < <(echo "$tasks_json" | jq -c '.results[]' 2>/dev/null)

	local total=${#task_ids[@]}
	log_info "Found $total tasks to move" >&2

	if [[ $total -eq 0 ]]; then
		local result
		result=$(json_obj_raw \
			"moved" "0" \
			"source_section" "$(json_escape "$source_section_id")" \
			"dest_section" "$(json_escape "$dest_section_id")")
		json_output "$result"
		return 0
	fi

	local moved=0
	local failed=0
	for i in "${!task_ids[@]}"; do
		local tid="${task_ids[$i]}"
		local tname="${task_names[$i]}"
		log_info "Moving ($((i + 1))/$total): $tname" >&2
		if td task move "id:$tid" --project "id:$project_id" --section "id:$dest_section_id" &>/dev/null; then
			moved=$((moved + 1))
		else
			log_warning "Failed to move: $tname" >&2
			failed=$((failed + 1))
		fi
	done

	local result
	result=$(json_obj_raw \
		"moved" "$moved" \
		"failed" "$failed" \
		"source_section" "$(json_escape "$source_section_id")" \
		"dest_section" "$(json_escape "$dest_section_id")")
	json_output "$result"
}

show_help() {
	echo "Usage: move-todoist-tasks.sh <source-section-url> <dest-section-url>"
	echo ""
	echo "Move all tasks from one Todoist section to another."
	echo ""
	echo "Arguments:"
	echo "  source-section-url   Todoist section URL to move tasks FROM"
	echo "  dest-section-url     Todoist section URL to move tasks TO"
	echo ""
	echo "Options:"
	echo "  --help               Show this help message"
}

main() {
	local source_url=""
	local dest_url=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		*)
			if [[ -z "$source_url" ]]; then
				source_url="$1"
			elif [[ -z "$dest_url" ]]; then
				dest_url="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "$source_url" || -z "$dest_url" ]]; then
		log_error "Both source and destination section URLs are required"
		show_help >&2
		return 1
	fi

	require_command "td" "npm install -g @doist/todoist-cli"
	move_tasks "$source_url" "$dest_url"
}

main "$@"
