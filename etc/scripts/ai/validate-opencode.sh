#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"

validate_skills() {
    local opencode_dir="$1"
    local skills_dir="$opencode_dir/skills"
    local errors=0

    log_header "Validating Skills" "📚"

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

        local skill_file="$skill_dir/SKILL.md"
        if [[ ! -f "$skill_file" ]]; then
            log_error "Skill '$skill_name' missing SKILL.md"
            errors=$((errors + 1))
            continue
        fi

        local size
        size=$(wc -c < "$skill_file" | tr -d ' ')
        if [[ "$size" -lt 10 ]]; then
            log_error "Skill '$skill_name' SKILL.md is empty or near-empty ($size bytes)"
            errors=$((errors + 1))
        fi
    done

    return $errors
}

validate_commands() {
    local opencode_dir="$1"
    local cmd_dir="$opencode_dir/command"
    local errors=0

    log_header "Validating Commands" "⚡"

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

        if ! head -5 "$cmd_file" | grep -q "^---" 2>/dev/null; then
            log_warning "Command '$cmd_name' may be missing frontmatter"
        fi

        local size
        size=$(wc -c < "$cmd_file" | tr -d ' ')
        if [[ "$size" -lt 10 ]]; then
            log_error "Command '$cmd_name' file is empty or near-empty ($size bytes)"
            errors=$((errors + 1))
        fi
    done

    return $errors
}

validate_agents() {
    local opencode_dir="$1"
    local agent_dir="$opencode_dir/agent"
    local errors=0

    log_header "Validating Agents" "🤖"

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

        local size
        size=$(wc -c < "$agent_file" | tr -d ' ')
        if [[ "$size" -lt 10 ]]; then
            log_error "Agent '$agent_name' file is empty or near-empty ($size bytes)"
            errors=$((errors + 1))
        fi
    done

    return $errors
}

validate_agents_md_refs() {
    local opencode_dir="$1"
    local agents_md="$opencode_dir/AGENTS.md"
    local errors=0

    log_header "Validating AGENTS.md References" "🔗"

    if [[ ! -f "$agents_md" ]]; then
        log_warning "No AGENTS.md found"
        return 0
    fi

    local referenced_skills
    referenced_skills=$(grep -oE 'skills/[a-z0-9_-]+' "$agents_md" 2>/dev/null | sort -u || echo "")

    while IFS= read -r ref; do
        if [[ -z "$ref" ]]; then
            continue
        fi
        local skill_path="$opencode_dir/$ref"
        if [[ ! -d "$skill_path" ]]; then
            log_error "AGENTS.md references '$ref' but directory does not exist"
            errors=$((errors + 1))
        fi
    done <<< "$referenced_skills"

    return $errors
}

check_deprecated_refs() {
    local opencode_dir="$1"
    local agents_md="$opencode_dir/AGENTS.md"
    local errors=0

    log_header "Checking Deprecated References" "⚠️"

    if [[ ! -f "$agents_md" ]]; then
        return 0
    fi

    local deprecated_dirs=()
    for dep_dir in "$opencode_dir"/*/_depreciated/; do
        if [[ -d "$dep_dir" ]]; then
            for item in "$dep_dir"*; do
                if [[ -e "$item" ]]; then
                    local item_name
                    item_name=$(basename "$item" .md)
                    if grep -q "$item_name" "$agents_md" 2>/dev/null; then
                        log_warning "AGENTS.md references deprecated item: $item_name (in $dep_dir)"
                        errors=$((errors + 1))
                    fi
                fi
            done
        fi
    done

    for dep_dir in "$opencode_dir"/skills/_depreciated/*/; do
        if [[ -d "$dep_dir" ]]; then
            local skill_name
            skill_name=$(basename "$dep_dir")
            if grep -q "$skill_name" "$agents_md" 2>/dev/null; then
                log_warning "AGENTS.md references deprecated skill: $skill_name"
                errors=$((errors + 1))
            fi
        fi
    done

    if [[ "$errors" -eq 0 ]]; then
        log_success "No deprecated references found"
    fi

    return $errors
}

show_help() {
    echo "Usage: validate-opencode.sh [opencode-directory]"
    echo ""
    echo "Validate OpenCode config: skills, commands, agents, and AGENTS.md references."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
}

main() {
    local opencode_dir="${1:-./src/opencode}"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) show_help; exit 0 ;;
            *) opencode_dir="$1"; shift ;;
        esac
    done

    log_header "OpenCode Config Validation" "🔍"

    local total_errors=0

    validate_skills "$opencode_dir" || total_errors=$((total_errors + $?))
    validate_commands "$opencode_dir" || total_errors=$((total_errors + $?))
    validate_agents "$opencode_dir" || total_errors=$((total_errors + $?))
    validate_agents_md_refs "$opencode_dir" || total_errors=$((total_errors + $?))
    check_deprecated_refs "$opencode_dir" || total_errors=$((total_errors + $?))

    if [[ "$total_errors" -eq 0 ]]; then
        log_success "All validations passed"
    else
        log_error "Found $total_errors issue(s)"
    fi

    echo "TOTAL_ERRORS=$total_errors"
}

main "$@"
