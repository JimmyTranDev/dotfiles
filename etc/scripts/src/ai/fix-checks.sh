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

get_pr_number() {
	local dir="$1"
	local pr_num
	pr_num=$(gh pr view --json number -q '.number' 2>/dev/null) || {
		log_error "No PR found for current branch"
		return 1
	}
	echo "$pr_num"
}

fetch_checks() {
	local dir="$1"
	local pr_num="$2"

	log_info "Fetching checks for PR #$pr_num" >&2

	local checks_json
	checks_json=$(gh pr checks "$pr_num" --json name,state,bucket,link 2>/dev/null || echo "[]")

	local failing_arr=()
	local passing_arr=()
	local total=0

	while IFS= read -r check; do
		[[ -z "$check" ]] && continue
		total=$((total + 1))

		local name state bucket
		name=$(echo "$check" | jq -r '.name')
		state=$(echo "$check" | jq -r '.state')
		bucket=$(echo "$check" | jq -r '.bucket')

		if [[ "$bucket" == "fail" ]]; then
			local log_content=""
			local run_id
			run_id=$(gh run list --json databaseId,name --jq ".[] | select(.name==\"$name\") | .databaseId" 2>/dev/null | head -1 || echo "")

			if [[ -n "$run_id" ]]; then
				log_content=$(gh run view "$run_id" --log-failed 2>/dev/null | tail -100 || echo "")
			fi

			local obj
			obj=$(json_obj_raw \
				"name" "$(json_escape "$name")" \
				"status" "$(json_escape "$state")" \
				"conclusion" "$(json_escape "$bucket")" \
				"log" "$(json_escape "$log_content")")
			failing_arr+=("$obj")
		else
			local obj
			obj=$(json_obj "name" "$name")
			passing_arr+=("$obj")
		fi
	done < <(echo "$checks_json" | jq -c '.[]' 2>/dev/null || true)

	local failing_json
	failing_json=$(json_arr_raw "${failing_arr[@]}")

	local passing_json
	passing_json=$(json_arr_raw "${passing_arr[@]}")

	local result
	result=$(json_obj_raw \
		"pr_number" "$pr_num" \
		"total_checks" "$total" \
		"failing" "$failing_json" \
		"passing" "$passing_json")

	json_output "$result"
}

show_help() {
	echo "Usage: fix-checks.sh [--pr <number>] [directory]"
	echo ""
	echo "Fetch failing CI checks from GitHub as JSON."
	echo ""
	echo "Options:"
	echo "  --pr <number>  PR number (auto-detected from current branch if omitted)"
	echo "  --help         Show this help message"
}

main() {
	local dir="."
	local pr_num=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			show_help
			exit 0
			;;
		--pr)
			pr_num="$2"
			shift 2
			;;
		*)
			dir="$1"
			shift
			;;
		esac
	done

	check_gh

	if [[ -z "$pr_num" ]]; then
		pr_num=$(get_pr_number "$dir")
	fi

	fetch_checks "$dir" "$pr_num"
}

main "$@"
