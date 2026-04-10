#!/bin/zsh

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$SCRIPT_DIR/common/logging.sh"

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

PR_JSON=$(gh pr list --author "@me" --state open --json number,title,url --limit 100 2>/dev/null) || {
	log_error "Failed to fetch PRs. Run 'gh auth login' first."
	exit 1
}

PR_COUNT=$(echo "$PR_JSON" | jq 'length') || {
	log_error "Failed to parse PR data"
	exit 1
}

if [[ "$PR_COUNT" -eq 0 ]]; then
	log_warning "No open PRs found in this repo"
	exit 0
fi

PR_DISPLAY=()
while IFS= read -r line; do
	PR_DISPLAY+=("$line")
done < <(echo "$PR_JSON" | jq -r '.[] | "#\(.number) \(.title)"')

SELECTED=$(printf "%s\n" "${PR_DISPLAY[@]}" | fzf --multi --prompt="Select PRs to post to Slack: ") || {
	log_warning "No PRs selected"
	exit 0
}

MESSAGE_LINES=()
while IFS= read -r selected_line; do
	PR_NUM="${selected_line%% *}"
	PR_NUM="${PR_NUM#\#}"
	if ! [[ "$PR_NUM" =~ ^[0-9]+$ ]]; then
		log_warning "Skipping invalid PR number: $PR_NUM"
		continue
	fi
	PR_LINE=$(echo "$PR_JSON" | jq -r --arg num "$PR_NUM" '.[] | select(.number == ($num | tonumber)) | "- \(.title) (\(.url))"')
	MESSAGE_LINES+=("$PR_LINE")
done <<<"$SELECTED"

if [[ ${#MESSAGE_LINES[@]} -eq 0 ]]; then
	log_warning "No valid PRs to post"
	exit 0
fi

MESSAGE=$(printf "%s\n" "${MESSAGE_LINES[@]}")

log_info "Posting to Slack:"
echo "$MESSAGE"
echo ""

PAYLOAD=$(jq -n --arg text "$MESSAGE" '{text: $text}')

CURL_CONFIG=$(mktemp)
RESPONSE_BODY=$(mktemp)
trap 'rm -f "$CURL_CONFIG" "$RESPONSE_BODY"' EXIT
printf 'url = "%s"\n' "$SLACK_FRONTEND_WEBHOOK_URL" >"$CURL_CONFIG"
chmod 600 "$CURL_CONFIG"

HTTP_STATUS=$(curl -s -o "$RESPONSE_BODY" -w "%{http_code}" \
	-X POST \
	-H "Content-Type: application/json" \
	-d "$PAYLOAD" \
	--config "$CURL_CONFIG")

if [[ "$HTTP_STATUS" == "200" ]]; then
	log_success "Posted ${#MESSAGE_LINES[@]} PR(s) to Slack"
else
	BODY=$(<"$RESPONSE_BODY")
	log_error "Failed to post to Slack (HTTP $HTTP_STATUS): $BODY"
	exit 1
fi
