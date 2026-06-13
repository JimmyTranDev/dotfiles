#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

# Vibrant Todoist palette (excludes dull charcoal/grey/taupe by default)
VIBRANT_COLORS=(
	berry_red red orange yellow olive_green lime_green green mint_green
	teal sky_blue light_blue blue grape violet lavender magenta salmon
)
GREY_COLORS=(charcoal grey taupe)

random_color() {
	local -a palette=("$@")
	local idx=$((RANDOM % ${#palette[@]}))
	echo "${palette[$idx]}"
}

randomize_colors() {
	local dry_run="$1"
	local include_greys="$2"

	local -a palette=("${VIBRANT_COLORS[@]}")
	if [[ "$include_greys" == "true" ]]; then
		palette+=("${GREY_COLORS[@]}")
	fi

	local projects_json
	projects_json=$(td project list --json --full 2>/dev/null)

	local updated=0
	local skipped=0
	local failed=0

	while IFS= read -r proj; do
		[[ -z "$proj" ]] && continue
		local pid pname pcolor
		pid=$(echo "$proj" | jq -r '.id')
		pname=$(echo "$proj" | jq -r '.name')
		pcolor=$(echo "$proj" | jq -r '.color // "grey"')

		# Skip the special Inbox project (cannot be recolored)
		if echo "$proj" | jq -e '.inboxProject == true' &>/dev/null; then
			log_info "Skipping Inbox: $pname" >&2
			skipped=$((skipped + 1))
			continue
		fi

		# Pick a new color that differs from the current one
		local new_color
		new_color=$(random_color "${palette[@]}")
		local attempts=0
		while [[ "$new_color" == "$pcolor" && $attempts -lt 10 ]]; do
			new_color=$(random_color "${palette[@]}")
			attempts=$((attempts + 1))
		done

		if [[ "$dry_run" == "true" ]]; then
			log_info "[dry-run] $pname: $pcolor -> $new_color" >&2
			updated=$((updated + 1))
			continue
		fi

		if td project update "id:$pid" --color "$new_color" &>/dev/null; then
			log_success "$pname: $pcolor -> $new_color" >&2
			updated=$((updated + 1))
		else
			log_warning "Failed to update: $pname" >&2
			failed=$((failed + 1))
		fi
	done < <(echo "$projects_json" | jq -c '.results[]' 2>/dev/null)

	local result
	result=$(json_obj_raw \
		"updated" "$updated" \
		"skipped" "$skipped" \
		"failed" "$failed" \
		"dry_run" "$dry_run")
	json_output "$result"
}

show_help() {
	echo "Usage: randomize-todoist-colors.sh [--dry-run] [--include-greys]"
	echo ""
	echo "Randomize the color of every Todoist project."
	echo ""
	echo "Options:"
	echo "  --dry-run         Show planned color changes without applying them"
	echo "  --include-greys   Include charcoal/grey/taupe in the palette"
	echo "  --help            Show this help message"
	echo ""
	echo "Notes:"
	echo "  - The special Inbox project is always skipped."
	echo "  - Each project is reassigned a color different from its current one."
}

main() {
	local dry_run="false"
	local include_greys="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		--dry-run)
			dry_run="true"
			shift
			;;
		--include-greys)
			include_greys="true"
			shift
			;;
		*)
			log_error "Unknown argument: $1"
			show_help >&2
			return 1
			;;
		esac
	done

	require_command "td" "pnpm add -g @doist/todoist-cli"
	require_command "jq" "brew install jq"

	if [[ -n "${PRI_TODOIST_API_TOKEN:-}" && -z "${TODOIST_API_TOKEN:-}" ]]; then
		export TODOIST_API_TOKEN="$PRI_TODOIST_API_TOKEN"
	fi

	randomize_colors "$dry_run" "$include_greys"
}

main "$@"
