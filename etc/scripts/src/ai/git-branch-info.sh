#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/git.sh"

get_branch_info() {
    local dir="${1:-.}"

    if ! git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        log_error "Not a git repository: $dir"
        return 1
    fi

    local current_branch
    current_branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "detached")

    local base_branch
    base_branch=$(find_base_branch "$dir")

    local ahead=0
    local behind=0
    if [[ "$base_branch" != "unknown" ]] && [[ "$current_branch" != "detached" ]]; then
        ahead=$(git -C "$dir" rev-list --count "$base_branch..$current_branch" 2>/dev/null || echo "0")
        behind=$(git -C "$dir" rev-list --count "$current_branch..$base_branch" 2>/dev/null || echo "0")
    fi

    local uncommitted
    uncommitted=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

    local staged
    staged=$(git -C "$dir" diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

    local diff_stat=""
    if [[ "$base_branch" != "unknown" ]] && [[ "$current_branch" != "detached" ]]; then
        diff_stat=$(git -C "$dir" diff --stat "$base_branch...$current_branch" 2>/dev/null | tail -1 || echo "")
    fi

    echo "CURRENT_BRANCH=$current_branch"
    echo "BASE_BRANCH=$base_branch"
    echo "AHEAD=$ahead"
    echo "BEHIND=$behind"
    echo "UNCOMMITTED=$uncommitted"
    echo "STAGED=$staged"
    echo "DIFF_STAT=$diff_stat"
}

show_help() {
    echo "Usage: git-branch-info.sh [directory]"
    echo ""
    echo "Output git branch context as KEY=VALUE pairs."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
}

main() {
    local dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) show_help; exit 0 ;;
            *) dir="$1"; shift ;;
        esac
    done

    get_branch_info "$dir"
}

main "$@"
