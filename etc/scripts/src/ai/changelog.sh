#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"

get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

generate_changelog() {
    local from_ref="$1"
    local to_ref="${2:-HEAD}"

    if [[ -z "$from_ref" ]]; then
        from_ref=$(get_last_tag)
    fi

    local range
    if [[ -n "$from_ref" ]]; then
        range="${from_ref}..${to_ref}"
        log_header "Changelog: $range" "📝"
    else
        range="$to_ref"
        log_header "Changelog: all commits to $to_ref" "📝"
    fi

    local commits
    commits=$(git log "$range" --pretty=format:"%s" --no-merges 2>/dev/null || echo "")

    if [[ -z "$commits" ]]; then
        log_info "No commits found in range"
        return 0
    fi

    local feats="" fixes="" chores="" refactors="" docs="" tests="" perfs="" others=""

    while IFS= read -r line; do
        case "$line" in
            feat*)    feats="${feats}- ${line}
" ;;
            fix*)     fixes="${fixes}- ${line}
" ;;
            chore*)   chores="${chores}- ${line}
" ;;
            refactor*) refactors="${refactors}- ${line}
" ;;
            docs*)    docs="${docs}- ${line}
" ;;
            test*)    tests="${tests}- ${line}
" ;;
            perf*)    perfs="${perfs}- ${line}
" ;;
            *)        others="${others}- ${line}
" ;;
        esac
    done <<< "$commits"

    if [[ -n "$feats" ]]; then
        echo "### Features"
        echo "$feats"
    fi
    if [[ -n "$fixes" ]]; then
        echo "### Bug Fixes"
        echo "$fixes"
    fi
    if [[ -n "$perfs" ]]; then
        echo "### Performance"
        echo "$perfs"
    fi
    if [[ -n "$refactors" ]]; then
        echo "### Refactoring"
        echo "$refactors"
    fi
    if [[ -n "$docs" ]]; then
        echo "### Documentation"
        echo "$docs"
    fi
    if [[ -n "$tests" ]]; then
        echo "### Tests"
        echo "$tests"
    fi
    if [[ -n "$chores" ]]; then
        echo "### Chores"
        echo "$chores"
    fi
    if [[ -n "$others" ]]; then
        echo "### Other"
        echo "$others"
    fi
}

show_help() {
    echo "Usage: changelog.sh [from-ref] [to-ref]"
    echo ""
    echo "Generate grouped changelog from git history."
    echo "Defaults: from last tag to HEAD."
    echo ""
    echo "Options:"
    echo "  --help    Show this help message"
}

main() {
    local from_ref=""
    local to_ref="HEAD"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --help) show_help; exit 0 ;;
            *)
                if [[ -z "$from_ref" ]]; then
                    from_ref="$1"
                else
                    to_ref="$1"
                fi
                shift
                ;;
        esac
    done

    generate_changelog "$from_ref" "$to_ref"
}

main "$@"
