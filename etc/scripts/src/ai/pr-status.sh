#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

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
		json_output "$(json_obj_raw "total" "0" "mine" "$mine" "prs" "[]")"
		return 0
	fi

	local result
	result=$(echo "$prs" | jq -c --argjson mine "$mine" '{
		total: length,
		mine: $mine,
		prs: [.[] | {
			number: .number,
			title: .title,
			branch: .headRefName,
			checks: (
				if (.statusCheckRollup == null or .statusCheckRollup == []) then "NONE"
				elif ([.statusCheckRollup[] | select(.conclusion == "FAILURE")] | length) > 0 then "FAILURE"
				elif ([.statusCheckRollup[] | select(.status == "IN_PROGRESS" or .status == "QUEUED" or .conclusion == "")] | length) > 0 then "PENDING"
				else "SUCCESS"
				end
			),
			review: (.reviewDecision // "PENDING"),
			mergeable: (.mergeable // "UNKNOWN")
		}]
	}')

	json_output "$result"
}

show_help() {
	log_info "Usage: pr-status.sh [OPTIONS]"
	log_info ""
	log_info "List open PRs with check/review/merge status."
	log_info ""
	log_info "Options:"
	log_info "  --mine    Filter to current user's PRs only"
	log_info "  --help    Show this help message"
}

main() {
	local mine="false"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--mine)
			mine="true"
			shift
			;;
		--help)
			show_help
			exit 0
			;;
		*) shift ;;
		esac
	done

	check_gh
	list_prs "$mine"
}

main "$@"
