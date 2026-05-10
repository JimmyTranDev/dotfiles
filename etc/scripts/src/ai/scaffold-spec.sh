#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"

resolve_filename() {
	local dir="$1"
	local name="$2"
	local filepath="$dir/$name.md"

	if [[ ! -f "$filepath" ]]; then
		echo "$filepath"
		return
	fi

	local counter=2
	while [[ -f "$dir/${name}-${counter}.md" ]]; do
		counter=$((counter + 1))
	done
	echo "$dir/${name}-${counter}.md"
}

create_spec() {
	local prefix="$1"
	local name="$2"
	local todoist_url="$3"
	local plans_dir="$4"

	local filename="${prefix}-${name}"
	local filepath
	filepath=$(resolve_filename "$plans_dir" "$filename")

	{
		if [[ -n "$todoist_url" ]]; then
			echo "---"
			echo "todoist: $todoist_url"
			echo "---"
			echo ""
		fi

		cat <<'TEMPLATE'
# TITLE

## Overview



## Architecture



## Data flow



## Tasks



## API contracts



## State changes



## Edge cases



## Testing approach



## Open questions

### Requirements



### Architecture



### Scope



### Conventions



### Risks

TEMPLATE
	} >"$filepath"

	echo "$filepath"
}

show_help() {
	echo "Usage: scaffold-spec.sh <prefix> <name> [OPTIONS]"
	echo ""
	echo "Create a plans/*.md file with standard section headers."
	echo ""
	echo "Arguments:"
	echo "  prefix    Spec filename prefix (e.g., review, security)"
	echo "  name      Descriptive kebab-case name (e.g., auth-module)"
	echo ""
	echo "Options:"
	echo "  --todoist <url>    Add Todoist URL to YAML frontmatter"
	echo "  --dir <path>      Plans directory (default: ./plans)"
	echo "  --help             Show this help message"
}

main() {
	local prefix=""
	local name=""
	local todoist_url=""
	local plans_dir="./plans"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--todoist)
			todoist_url="$2"
			shift 2
			;;
		--dir)
			plans_dir="$2"
			shift 2
			;;
		--help)
			show_help
			exit 0
			;;
		*)
			if [[ -z "$prefix" ]]; then
				prefix="$1"
			elif [[ -z "$name" ]]; then
				name="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "$prefix" ]] || [[ -z "$name" ]]; then
		log_error "Both prefix and name are required"
		show_help
		return 1
	fi

	mkdir -p "$plans_dir"

	local filepath
	filepath=$(create_spec "$prefix" "$name" "$todoist_url" "$plans_dir")

	log_success "Created spec: $filepath"
	echo "SPEC_FILE=$filepath"
}

main "$@"
