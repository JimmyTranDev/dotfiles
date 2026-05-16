#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/json.sh"

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

	python3 -c "
import json, sys

inline = json.loads('''$inline_comments''') if '''$inline_comments''' != '[]' else []
pr_data = json.loads('''$pr_comments''')
include_resolved = '$include_resolved' == 'true'
pr_number = int('$pr_number')

results = []

for c in inline:
    if isinstance(c, dict):
        resolved = c.get('position') is None and c.get('line') is None
        if not include_resolved and resolved:
            continue
        results.append({
            'type': 'inline',
            'reviewer': c.get('user', {}).get('login', 'unknown'),
            'file': c.get('path', ''),
            'line': c.get('line') or c.get('original_line', 0),
            'body': c.get('body', ''),
            'state': 'resolved' if resolved else 'pending',
            'url': c.get('html_url', ''),
            'created_at': c.get('created_at', '')
        })

for r in pr_data.get('reviews', []):
    if isinstance(r, dict) and r.get('body'):
        results.append({
            'type': 'review',
            'reviewer': r.get('author', {}).get('login', 'unknown'),
            'file': '',
            'line': 0,
            'body': r.get('body', ''),
            'state': r.get('state', 'PENDING').lower(),
            'url': '',
            'created_at': r.get('submittedAt', '')
        })

output = {'pr_number': pr_number, 'count': len(results), 'comments': results}
print(json.dumps(output, separators=(',', ':')))
" 2>/dev/null

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
