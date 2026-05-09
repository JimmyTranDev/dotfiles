#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../common/logging.sh"
source "$SCRIPT_DIR/../common/utility.sh"

get_last_monday() {
    if [[ "$(uname)" == "Darwin" ]]; then
        local day_of_week
        day_of_week=$(date +%u)
        local days_since_monday=$(( day_of_week - 1 ))
        date -v-${days_since_monday}d +%Y-%m-%d
    else
        date -d "last monday" +%Y-%m-%d
    fi
}

gather_commits() {
    local repo_dir="$1"
    local since="$2"
    local author="$3"

    local repo_name
    repo_name=$(basename "$repo_dir")

    local commits
    commits=$(git -C "$repo_dir" log --since="$since" --author="$author" --pretty=format:"%H|%ad|%s" --date=short 2>/dev/null || echo "")

    if [[ -z "$commits" ]]; then
        return
    fi

    while IFS= read -r line; do
        local hash="${line%%|*}"
        local rest="${line#*|}"
        local date="${rest%%|*}"
        local message="${rest#*|}"
        echo "${repo_name}|${hash:0:8}|${date}|${message}"
    done <<< "$commits"
}

extract_ticket_keys() {
    local commits="$1"
    echo "$commits" | grep -oE '[A-Z]+-[0-9]+' | sort -u
}

fetch_jira_tickets() {
    local keys="$1"

    if ! command -v acli &>/dev/null; then
        log_warning "acli not found, skipping Jira lookups"
        return
    fi

    while IFS= read -r key; do
        if [[ -z "$key" ]]; then
            continue
        fi
        local info
        info=$(acli jira workitem view --key "$key" --json 2>/dev/null || echo "")
        if [[ -n "$info" ]]; then
            echo "TICKET|${key}|${info}"
        fi
    done <<< "$keys"
}

output_human() {
    local commits="$1"
    local tickets="$2"
    local since="$3"

    log_header "Weekly Summary (since $since)"

    if [[ -z "$commits" ]]; then
        log_info "No commits found since $since"
        return
    fi

    local commit_count
    commit_count=$(echo "$commits" | wc -l | tr -d ' ')
    local ticket_keys
    ticket_keys=$(extract_ticket_keys "$commits")
    local ticket_count=0
    if [[ -n "$ticket_keys" ]]; then
        ticket_count=$(echo "$ticket_keys" | wc -l | tr -d ' ')
    fi

    echo ""
    echo "TOTAL_COMMITS=$commit_count"
    echo "TOTAL_TICKETS=$ticket_count"
    echo ""

    if [[ -n "$ticket_keys" ]]; then
        echo "--- Commits by Ticket ---"
        while IFS= read -r key; do
            if [[ -z "$key" ]]; then
                continue
            fi
            echo ""
            echo "[$key]"
            echo "$commits" | grep "$key" | while IFS='|' read -r repo hash date message; do
                echo "  $date $repo $hash $message"
            done
        done <<< "$ticket_keys"
    fi

    echo ""
    echo "--- Unlinked Commits ---"
    echo "$commits" | while IFS='|' read -r repo hash date message; do
        if ! echo "$message" | grep -qE '[A-Z]+-[0-9]+'; then
            echo "  $date $repo $hash $message"
        fi
    done
}

output_json() {
    local commits="$1"
    local since="$2"

    echo "{"
    echo "  \"since\": \"$since\","
    echo "  \"commits\": ["

    local first=true
    if [[ -n "$commits" ]]; then
        while IFS='|' read -r repo hash date message; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            local escaped_message
            escaped_message=$(echo "$message" | sed 's/"/\\"/g')
            printf '    {"repo": "%s", "hash": "%s", "date": "%s", "message": "%s"}' "$repo" "$hash" "$date" "$escaped_message"
        done <<< "$commits"
    fi

    echo ""
    echo "  ],"

    echo "  \"ticket_keys\": ["
    local keys
    keys=$(extract_ticket_keys "$commits")
    first=true
    if [[ -n "$keys" ]]; then
        while IFS= read -r key; do
            if [[ -z "$key" ]]; then
                continue
            fi
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            printf '    "%s"' "$key"
        done <<< "$keys"
    fi
    echo ""
    echo "  ]"
    echo "}"
}

show_help() {
    cat << 'EOF'
Usage: weekly-summary.sh [options]

Gather this week's git commits across repos and extract Jira ticket keys.

Options:
  --since <date>    Start date (default: last Monday, YYYY-MM-DD)
  --dir <path>      Base directory to scan for repos (default: current repo only)
  --json            Output as JSON
  --help            Show this help message
EOF
}

main() {
    local since=""
    local base_dir=""
    local json_output=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --since) since="$2"; shift 2 ;;
            --dir) base_dir="$2"; shift 2 ;;
            --json) json_output=true; shift ;;
            --help) show_help; exit 0 ;;
            *) log_error "Unknown option: $1"; show_help; exit 1 ;;
        esac
    done

    if [[ -z "$since" ]]; then
        since=$(get_last_monday)
    fi

    local author
    author=$(git config user.name 2>/dev/null || echo "")
    if [[ -z "$author" ]]; then
        log_error "Could not determine git user.name"
        exit 1
    fi

    local all_commits=""

    if [[ -n "$base_dir" ]]; then
        local repos
        repos=$(find_git_repos "$base_dir" 3)
        while IFS= read -r repo; do
            if [[ -z "$repo" ]]; then
                continue
            fi
            local repo_commits
            repo_commits=$(gather_commits "${base_dir%/}/$repo" "$since" "$author")
            if [[ -n "$repo_commits" ]]; then
                if [[ -n "$all_commits" ]]; then
                    all_commits="${all_commits}
${repo_commits}"
                else
                    all_commits="$repo_commits"
                fi
            fi
        done <<< "$repos"
    else
        all_commits=$(gather_commits "." "$since" "$author")
    fi

    if [[ "$json_output" == "true" ]]; then
        output_json "$all_commits" "$since"
    else
        output_human "$all_commits" "" "$since"
    fi
}

main "$@"
