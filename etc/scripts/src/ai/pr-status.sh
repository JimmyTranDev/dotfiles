#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/logging.sh"

check_gh() {
    if ! command -v gh &>/dev/null; then
        log_error "gh CLI is required but not installed"
        return 1
    fi
}

list_prs() {
    local mine="${1:-false}"

    log_header "Open Pull Requests" "📋"

    local gh_args=(pr list --state open --json number,title,headRefName,statusCheckRollup,reviewDecision,mergeable)

    if [[ "$mine" == "true" ]]; then
        gh_args+=(--author "@me")
    fi

    local prs
    prs=$(gh "${gh_args[@]}" 2>/dev/null)

    if [[ -z "$prs" ]] || [[ "$prs" == "[]" ]]; then
        log_info "No open pull requests found"
        return 0
    fi

    local count
    count=$(echo "$prs" | jq length)

    for ((i = 0; i < count; i++)); do
        local number title branch review_decision mergeable check_status

        number=$(echo "$prs" | jq -r ".[$i].number")
        title=$(echo "$prs" | jq -r ".[$i].title")
        branch=$(echo "$prs" | jq -r ".[$i].headRefName")
        review_decision=$(echo "$prs" | jq -r ".[$i].reviewDecision // \"PENDING\"")
        mergeable=$(echo "$prs" | jq -r ".[$i].mergeable // \"UNKNOWN\"")

        local checks_json
        checks_json=$(echo "$prs" | jq -r ".[$i].statusCheckRollup")
        check_status="NONE"

        if [[ "$checks_json" != "null" ]] && [[ "$checks_json" != "[]" ]]; then
            local has_failure has_pending
            has_failure=$(echo "$checks_json" | jq '[.[] | select(.conclusion == "FAILURE")] | length')
            has_pending=$(echo "$checks_json" | jq '[.[] | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .conclusion == "")] | length')

            if [[ "$has_failure" -gt 0 ]]; then
                check_status="FAILURE"
            elif [[ "$has_pending" -gt 0 ]]; then
                check_status="PENDING"
            else
                check_status="SUCCESS"
            fi
        fi

        echo "PR_NUMBER=$number"
        echo "PR_TITLE=$title"
        echo "PR_BRANCH=$branch"
        echo "PR_CHECKS=$check_status"
        echo "PR_REVIEW=$review_decision"
        echo "PR_MERGEABLE=$mergeable"
        echo "---"
    done
}

show_help() {
    echo "Usage: pr-status.sh [OPTIONS]"
    echo ""
    echo "List open PRs with check/review/merge status."
    echo ""
    echo "Options:"
    echo "  --mine    Filter to current user's PRs only"
    echo "  --help    Show this help message"
}

main() {
    local mine="false"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mine) mine="true"; shift ;;
            --help) show_help; exit 0 ;;
            *) shift ;;
        esac
    done

    check_gh
    list_prs "$mine"
}

main "$@"
