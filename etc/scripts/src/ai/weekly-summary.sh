#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

get_last_monday() {
	if [[ "$(uname)" == "Darwin" ]]; then
		local day_of_week
		day_of_week=$(date +%u)
		local days_since_monday=$((day_of_week - 1))
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
	done <<<"$commits"
}

extract_ticket_keys() {
	local commits="$1"
	echo "$commits" | grep -oE '[A-Z]+-[0-9]+' | sort -u
}

show_help() {
	cat <<'EOF'
Usage: weekly-summary.sh [options]

Gather this week's git commits across repos and extract Jira ticket keys.
Outputs JSON to stdout.

Options:
  --since <date>    Start date (default: last Monday, YYYY-MM-DD)
  --dir <path>      Base directory to scan for repos (default: current repo only)
  --help            Show this help message
EOF
}

main() {
	local since=""
	local base_dir=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--since)
			since="$2"
			shift 2
			;;
		--dir)
			base_dir="$2"
			shift 2
			;;
		--help)
			show_help
			exit 0
			;;
		*)
			log_error "Unknown option: $1"
			show_help
			exit 1
			;;
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
		done <<<"$repos"
	else
		all_commits=$(gather_commits "." "$since" "$author")
	fi

	# Build JSON safely using jq
	local commits_json="[]"
	if [[ -n "$all_commits" ]]; then
		commits_json=$(echo "$all_commits" | while IFS='|' read -r repo hash date message; do
			jq -nc --arg repo "$repo" --arg hash "$hash" --arg date "$date" --arg message "$message" \
				'{repo: $repo, hash: $hash, date: $date, message: $message}'
		done | jq -sc '.')
	fi

	local keys_json="[]"
	if [[ -n "$all_commits" ]]; then
		local keys
		keys=$(extract_ticket_keys "$all_commits")
		if [[ -n "$keys" ]]; then
			keys_json=$(echo "$keys" | jq -R . | jq -sc '.')
		fi
	fi

	jq -nc --arg since "$since" --argjson commits "$commits_json" --argjson keys "$keys_json" \
		'{since: $since, commits: $commits, ticket_keys: $keys}'
}

main "$@"
