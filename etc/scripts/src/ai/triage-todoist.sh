#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

extract_section_id() {
	local url="$1"
	local section_id
	# Section URLs: .../section/name-ID where ID is alphanumeric (e.g., 6f29FXGQfv24xCqG)
	section_id=$(echo "$url" | grep -oE '[A-Za-z0-9]+$' || echo "")
	if [[ -z "$section_id" ]]; then
		log_error "Could not extract section ID from URL: $url"
		return 1
	fi
	echo "$section_id"
}

priority_to_api() {
	local p="$1"
	case "$p" in
	p1) echo "4" ;;
	p2) echo "3" ;;
	p3) echo "2" ;;
	p4) echo "1" ;;
	*) echo "" ;;
	esac
}

fetch_tasks() {
	local section_url="$1"
	local priority_filter="$2"

	local section_id
	section_id=$(extract_section_id "$section_url")

	log_info "Fetching tasks for section $section_id" >&2

	local tasks_json
	tasks_json=$(td task list --section-id "$section_id" --json 2>/dev/null || echo "[]")

	local api_priority=""
	if [[ -n "$priority_filter" ]]; then
		api_priority=$(priority_to_api "$priority_filter")
		if [[ -z "$api_priority" ]]; then
			log_error "Invalid priority: $priority_filter (use p1, p2, p3, or p4)"
			return 1
		fi
		tasks_json=$(echo "$tasks_json" | jq -c "[.[] | select(.priority == $api_priority)]")
	fi

	local total
	total=$(echo "$tasks_json" | jq 'length')

	local tasks_arr=()
	while IFS= read -r task; do
		[[ -z "$task" ]] && continue
		local obj
		obj=$(echo "$task" | jq -c '{
			id: (.id | tostring),
			content: .content,
			priority: .priority,
			labels: (.labels // []),
			due_date: (.due.date // null),
			description: (.description // ""),
			url: (.url // "")
		}')
		tasks_arr+=("$obj")
	done < <(echo "$tasks_json" | jq -c '.[]' 2>/dev/null || true)

	local tasks_result
	tasks_result=$(json_arr_raw "${tasks_arr[@]}")

	local result
	result=$(json_obj_raw \
		"section_id" "$(json_escape "$section_id")" \
		"total" "$total" \
		"tasks" "$tasks_result")

	json_output "$result"
}

show_help() {
	echo "Usage: triage-todoist.sh <section-url> [--priority <p1|p2|p3|p4>]"
	echo ""
	echo "Fetch and filter Todoist tasks as JSON."
	echo ""
	echo "Options:"
	echo "  --priority <p1|p2|p3|p4>  Filter by priority level"
	echo "  --help                    Show this help message"
}

main() {
	local section_url=""
	local priority=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--priority)
			priority="$2"
			shift 2
			;;
		*)
			if [[ -z "$section_url" ]]; then
				section_url="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "$section_url" ]]; then
		log_error "Section URL is required"
		show_help >&2
		return 1
	fi

	require_command "td" "pip install todoist-cli"
	fetch_tasks "$section_url" "$priority"
}

main "$@"
