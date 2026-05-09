#!/bin/bash

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/logging.sh"

main() {
	if ! command -v gh &>/dev/null; then
		log_error "gh (GitHub CLI) is required but not installed"
		exit 1
	fi

	if ! command -v fzf &>/dev/null; then
		log_error "fzf is required but not installed"
		exit 1
	fi

	if ! command -v jq &>/dev/null; then
		log_error "jq is required but not installed"
		exit 1
	fi

	if [[ -z "$SLACK_FRONTEND_WEBHOOK_URL" ]]; then
		log_error "SLACK_FRONTEND_WEBHOOK_URL is not set"
		log_info "Add it to ~/Programming/JimmyTranDev/secrets/env.sh"
		exit 1
	fi

	if ! git rev-parse --is-inside-work-tree &>/dev/null; then
		log_error "Not inside a git repository"
		exit 1
	fi

	log_info "Fetching open PRs..."

	local pr_json
	pr_json=$(gh pr list --author "@me" --state open --json number,title,url --limit 100 2>/dev/null) || {
		log_error "Failed to fetch PRs. Run 'gh auth login' first."
		exit 1
	}

	local pr_count
	pr_count=$(echo "$pr_json" | jq 'length') || {
		log_error "Failed to parse PR data"
		exit 1
	}

	if [[ "$pr_count" -eq 0 ]]; then
		log_warning "No open PRs found in this repo"
		exit 0
	fi

	local pr_display=()
	while IFS= read -r line; do
		pr_display+=("$line")
	done < <(echo "$pr_json" | jq -r '.[] | "#\(.number) \(.title)"')

	local selected
	selected=$(printf "%s\n" "${pr_display[@]}" | fzf --multi --prompt="Select PRs to post to Slack: ") || {
		log_warning "No PRs selected"
		exit 0
	}

	local message_lines=()
	while IFS= read -r selected_line; do
		local pr_num="${selected_line%% *}"
		pr_num="${pr_num#\#}"
		if ! [[ "$pr_num" =~ ^[0-9]+$ ]]; then
			log_warning "Skipping invalid PR number: $pr_num"
			continue
		fi
		local pr_line
		pr_line=$(echo "$pr_json" | jq -r --arg num "$pr_num" '.[] | select(.number == ($num | tonumber)) | "- \(.title) (\(.url))"')
		message_lines+=("$pr_line")
	done <<<"$selected"

	if [[ ${#message_lines[@]} -eq 0 ]]; then
		log_warning "No valid PRs to post"
		exit 0
	fi

	local message
	message=$(printf "%s\n" "${message_lines[@]}")

	log_info "Posting to Slack:"
	echo "$message"
	echo ""

	local payload
	payload=$(jq -n --arg text "$message" '{text: $text}')

	local curl_config
	curl_config=$(mktemp)
	local response_body
	response_body=$(mktemp)
	trap 'rm -f "$curl_config" "$response_body"' EXIT
	printf 'url = "%s"\n' "$SLACK_FRONTEND_WEBHOOK_URL" >"$curl_config"
	chmod 600 "$curl_config"

	local http_status
	http_status=$(curl -s -o "$response_body" -w "%{http_code}" \
		-X POST \
		-H "Content-Type: application/json" \
		-d "$payload" \
		--config "$curl_config")

	if [[ "$http_status" == "200" ]]; then
		log_success "Posted ${#message_lines[@]} PR(s) to Slack"
	else
		local body
		body=$(<"$response_body")
		log_error "Failed to post to Slack (HTTP $http_status): $body"
		exit 1
	fi
}

main "$@"
