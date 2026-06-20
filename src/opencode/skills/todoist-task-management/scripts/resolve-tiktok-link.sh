#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../../../etc/scripts/utils/common.sh"

resolve() {
	local url="$1"

	log_info "Resolving TikTok link via oEmbed" >&2

	# TikTok short URLs (vt.tiktok.com/...) return a generic page when scraped,
	# but the public oEmbed endpoint returns structured metadata.
	local oembed
	if ! oembed=$(curl -fsSL "https://www.tiktok.com/oembed?url=${url}" 2>/dev/null); then
		log_error "oEmbed request failed for: $url"
		return 1
	fi

	if ! echo "$oembed" | jq -e . &>/dev/null; then
		log_error "oEmbed returned non-JSON for: $url"
		return 1
	fi

	local result
	result=$(echo "$oembed" | jq -c '{
		url: "'"$url"'",
		title: (.title // null),
		author_name: (.author_name // null),
		author_url: (.author_url // null)
	}')
	json_output "$result"
}

show_help() {
	echo "Usage: resolve-tiktok-link.sh <tiktok-url>"
	echo ""
	echo "Resolve a TikTok link (including vt.tiktok.com short links) to its"
	echo "title and author via the public oEmbed API. Use this instead of"
	echo "scraping, which returns a generic 'TikTok - Make Your Day' page."
	echo ""
	echo "Outputs JSON: {url, title, author_name, author_url}"
	echo ""
	echo "Options:"
	echo "  --help, -h   Show this help message"
}

main() {
	local url=""

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help | -h)
			show_help
			exit 0
			;;
		*)
			if [[ -z "$url" ]]; then
				url="$1"
			fi
			shift
			;;
		esac
	done

	if [[ -z "$url" ]]; then
		log_error "A TikTok URL is required"
		show_help >&2
		return 1
	fi

	require_command "curl" "preinstalled on macOS"
	require_command "jq" "brew install jq"
	resolve "$url"
}

main "$@"
