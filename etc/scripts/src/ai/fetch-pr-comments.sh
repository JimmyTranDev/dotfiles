#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

show_help() {
	cat <<'EOF'
Usage: fetch-pr-comments.sh [options] [PR number or URL]

Fetch PR review comments and output JSON.

OPTIONS:
  --resolved      Include resolved comments (default: unresolved only)
  -h, --help      Show this help message

ARGUMENTS:
  PR ref          PR number or URL (default: current branch's PR)
EOF
}

get_pr_number() {
	local pr_ref="$1"

	if [[ -n "$pr_ref" ]]; then
		if [[ "$pr_ref" =~ ^[0-9]+$ ]]; then
			echo "$pr_ref"
			return
		fi
		local pr_num
		pr_num=$(echo "$pr_ref" | grep -oE '[0-9]+$' || true)
		if [[ -n "$pr_num" ]]; then
			echo "$pr_num"
			return
		fi
	fi

	gh pr view --json number -q '.number' 2>/dev/null || {
		log_error "No PR found for current branch"
		exit 1
	}
}

get_repo_info() {
	gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null || {
		log_error "Could not determine repository"
		exit 1
	}
}

fetch_comments() {
	local pr_number="$1"
	local include_resolved="$2"
	local repo_info
	repo_info=$(get_repo_info)

	local owner
	owner=$(echo "$repo_info" | cut -d'/' -f1)
	local repo
	repo=$(echo "$repo_info" | cut -d'/' -f2)

	local inline_comments
	inline_comments=$(gh api "repos/$owner/$repo/pulls/$pr_number/comments" --paginate 2>/dev/null || echo "[]")

	local pr_comments
	pr_comments=$(gh pr view "$pr_number" --json comments,reviews 2>/dev/null || echo '{"comments":[],"reviews":[]}')

	local result
	result=$(jq -n \
		--argjson inline "$inline_comments" \
		--argjson pr_data "$pr_comments" \
		--argjson include_resolved "$(if [[ "$include_resolved" == "true" ]]; then echo "true"; else echo "false"; fi)" \
		--argjson pr_num "$pr_number" '
		{
			pr_number: $pr_num,
			count: 0,
			comments: []
		} | .comments = (
			[
				($inline | if type == "array" then .[] else empty end |
					select(type == "object") |
					{
						resolved: ((.position == null) and (.line == null)),
						data: .
					} |
					select($include_resolved or (.resolved | not)) |
					{
						type: "inline",
						reviewer: (.data.user.login // "unknown"),
						file: (.data.path // ""),
						line: (.data.line // .data.original_line // 0),
						body: (.data.body // ""),
						state: (if .resolved then "resolved" else "pending" end),
						url: (.data.html_url // ""),
						created_at: (.data.created_at // "")
					}
				),
				($pr_data.reviews // [] | .[] |
					select(type == "object") |
					select(.body != null and .body != "") |
					{
						type: "review",
						reviewer: (.author.login // "unknown"),
						file: "",
						line: 0,
						body: (.body // ""),
						state: ((.state // "PENDING") | ascii_downcase),
						url: "",
						created_at: (.submittedAt // "")
					}
				)
			]
		) | .count = (.comments | length)
	')

	printf '%s\n' "$result"
}

main() {
	local pr_ref=""
	local include_resolved=false

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--resolved) include_resolved=true; shift ;;
		-h | --help) show_help; exit 0 ;;
		*) pr_ref="$1"; shift ;;
		esac
	done

	local pr_number
	pr_number=$(get_pr_number "$pr_ref")
	log_info "Fetching comments for PR #$pr_number..."

	fetch_comments "$pr_number" "$include_resolved"
}

main "$@"
