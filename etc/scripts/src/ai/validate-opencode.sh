#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

TOTAL_ERRORS=0
TOTAL_WARNINGS=0
ISSUES_JSON=""
SKILLS_COUNT=0
COMMANDS_COUNT=0
AGENTS_COUNT=0

add_issue() {
	local type="$1"
	local category="$2"
	local item="$3"
	local message="$4"

	local issue
	issue=$(json_obj "type" "$type" "category" "$category" "item" "$item" "message" "$message")
	if [[ -n "$ISSUES_JSON" ]]; then
		ISSUES_JSON="${ISSUES_JSON},${issue}"
	else
		ISSUES_JSON="$issue"
	fi

	if [[ "$type" == "error" ]]; then
		TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
	else
		TOTAL_WARNINGS=$((TOTAL_WARNINGS + 1))
	fi
}

validate_skills() {
	local opencode_dir="$1"
	local skills_dir="$opencode_dir/skills"

	log_info "Validating skills"

	if [[ ! -d "$skills_dir" ]]; then
		log_warning "No skills directory found at $skills_dir"
		return 0
	fi

	for skill_dir in "$skills_dir"/*/; do
		if [[ ! -d "$skill_dir" ]]; then
			continue
		fi

		local skill_name
		skill_name=$(basename "$skill_dir")

		if [[ "$skill_name" == "_depreciated" ]]; then
			continue
		fi

		SKILLS_COUNT=$((SKILLS_COUNT + 1))

		local skill_file="$skill_dir/SKILL.md"
		if [[ ! -f "$skill_file" ]]; then
			log_error "Skill '$skill_name' missing SKILL.md"
			add_issue "error" "skill" "$skill_name" "missing SKILL.md"
			continue
		fi

		local size
		size=$(wc -c <"$skill_file" | tr -d ' ')
		if [[ "$size" -lt 10 ]]; then
			log_error "Skill '$skill_name' SKILL.md is empty or near-empty ($size bytes)"
			add_issue "error" "skill" "$skill_name" "SKILL.md is empty or near-empty ($size bytes)"
		fi
	done
}

validate_commands() {
	local opencode_dir="$1"
	local cmd_dir="$opencode_dir/command"

	log_info "Validating commands"

	if [[ ! -d "$cmd_dir" ]]; then
		log_warning "No command directory found at $cmd_dir"
		return 0
	fi

	for cmd_file in "$cmd_dir"/*.md; do
		if [[ ! -f "$cmd_file" ]]; then
			continue
		fi

		local cmd_name
		cmd_name=$(basename "$cmd_file" .md)
		COMMANDS_COUNT=$((COMMANDS_COUNT + 1))

		if ! head -5 "$cmd_file" | grep -q "^---" 2>/dev/null; then
			log_warning "Command '$cmd_name' may be missing frontmatter"
			add_issue "warning" "command" "$cmd_name" "may be missing frontmatter"
		fi

		local size
		size=$(wc -c <"$cmd_file" | tr -d ' ')
		if [[ "$size" -lt 10 ]]; then
			log_error "Command '$cmd_name' file is empty or near-empty ($size bytes)"
			add_issue "error" "command" "$cmd_name" "file is empty or near-empty ($size bytes)"
		fi
	done
}

validate_agents() {
	local opencode_dir="$1"
	local agent_dir="$opencode_dir/agent"

	log_info "Validating agents"

	if [[ ! -d "$agent_dir" ]]; then
		log_warning "No agent directory found at $agent_dir"
		return 0
	fi

	for agent_file in "$agent_dir"/*.md; do
		if [[ ! -f "$agent_file" ]]; then
			continue
		fi

		local agent_name
		agent_name=$(basename "$agent_file" .md)
		AGENTS_COUNT=$((AGENTS_COUNT + 1))

		local size
		size=$(wc -c <"$agent_file" | tr -d ' ')
		if [[ "$size" -lt 10 ]]; then
			log_error "Agent '$agent_name' file is empty or near-empty ($size bytes)"
			add_issue "error" "agent" "$agent_name" "file is empty or near-empty ($size bytes)"
		fi
	done
}

validate_claude_md_refs() {
	local opencode_dir="$1"
	local claude_md="$opencode_dir/CLAUDE.md"

	log_info "Validating CLAUDE.md references"

	if [[ ! -f "$claude_md" ]]; then
		log_warning "No CLAUDE.md found"
		return 0
	fi

	local referenced_skills
	referenced_skills=$(grep -oE 'skills/[a-z0-9_-]+' "$claude_md" 2>/dev/null | sort -u || echo "")

	while IFS= read -r ref; do
		if [[ -z "$ref" ]]; then
			continue
		fi
		local skill_path="$opencode_dir/$ref"
		if [[ ! -d "$skill_path" ]]; then
			log_error "CLAUDE.md references '$ref' but directory does not exist"
			add_issue "error" "claude_md" "$ref" "referenced directory does not exist"
		fi
	done <<<"$referenced_skills"
}

check_deprecated_refs() {
	local opencode_dir="$1"
	local claude_md="$opencode_dir/CLAUDE.md"

	log_info "Checking deprecated references"

	if [[ ! -f "$claude_md" ]]; then
		return 0
	fi

	for dep_dir in "$opencode_dir"/*/_depreciated/; do
		if [[ -d "$dep_dir" ]]; then
			for item in "$dep_dir"*; do
				if [[ -e "$item" ]]; then
					local item_name
					item_name=$(basename "$item" .md)
					if grep -q "$item_name" "$claude_md" 2>/dev/null; then
						log_warning "CLAUDE.md references deprecated item: $item_name"
						add_issue "warning" "deprecated" "$item_name" "referenced in CLAUDE.md but deprecated"
					fi
				fi
			done
		fi
	done

	for dep_dir in "$opencode_dir"/skills/_depreciated/*/; do
		if [[ -d "$dep_dir" ]]; then
			local skill_name
			skill_name=$(basename "$dep_dir")
			if grep -q "$skill_name" "$claude_md" 2>/dev/null; then
				log_warning "CLAUDE.md references deprecated skill: $skill_name"
				add_issue "warning" "deprecated" "$skill_name" "deprecated skill referenced in CLAUDE.md"
			fi
		fi
	done
}

show_help() {
	echo "Usage: validate-opencode.sh [opencode-directory]"
	echo ""
	echo "Validate OpenCode config: skills, commands, agents, and CLAUDE.md references."
	echo ""
	echo "Options:"
	echo "  --help    Show this help message"
}

main() {
	local opencode_dir="${1:-./src/opencode}"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		*)
			opencode_dir="$1"
			shift
			;;
		esac
	done

	log_info "Validating OpenCode config"

	validate_skills "$opencode_dir"
	validate_commands "$opencode_dir"
	validate_agents "$opencode_dir"
	validate_claude_md_refs "$opencode_dir"
	check_deprecated_refs "$opencode_dir"

	if [[ "$TOTAL_ERRORS" -eq 0 ]] && [[ "$TOTAL_WARNINGS" -eq 0 ]]; then
		log_success "All validations passed"
	else
		log_error "Found $TOTAL_ERRORS error(s) and $TOTAL_WARNINGS warning(s)"
	fi

	local errors_json="[]"
	local warnings_json="[]"
	if [[ -n "$ISSUES_JSON" ]]; then
		local all_issues="[$ISSUES_JSON]"
		errors_json=$(printf '%s' "$all_issues" | jq -c '[.[] | select(.type == "error")]')
		warnings_json=$(printf '%s' "$all_issues" | jq -c '[.[] | select(.type == "warning")]')
	fi

	json_output "$(json_obj_raw \
		"total_errors" "$TOTAL_ERRORS" \
		"total_warnings" "$TOTAL_WARNINGS" \
		"errors" "$errors_json" \
		"warnings" "$warnings_json" \
		"skills_count" "$SKILLS_COUNT" \
		"commands_count" "$COMMANDS_COUNT" \
		"agents_count" "$AGENTS_COUNT")"
}

main "$@"
