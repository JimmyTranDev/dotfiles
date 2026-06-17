#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

# Resolve a (possibly relative) href against a base page URL.
# Echoes the absolute URL, or nothing if the href should be skipped.
resolve_url() {
	local href="$1"
	local base="$2"

	case "$href" in
	"" | "#"* | "javascript:"* | "mailto:"* | "tel:"* | "data:"*)
		return 0
		;;
	http://* | https://*)
		printf '%s' "$href"
		;;
	//*)
		local scheme="${base%%://*}"
		printf '%s:%s' "$scheme" "$href"
		;;
	/*)
		local origin="${base%%/*}//${base#*://}"
		origin="${base%%://*}://${base#*://}"
		origin="${origin%%/*}"
		# Reconstruct scheme://host
		local scheme="${base%%://*}"
		local host="${base#*://}"
		host="${host%%/*}"
		printf '%s://%s%s' "$scheme" "$host" "$href"
		;;
	*)
		# Relative to the directory of the base URL
		local dir="${base%/*}"
		printf '%s/%s' "$dir" "$href"
		;;
	esac
}

get_page_links() {
	local url="$1"
	local filter="$2"

	log_header "Fetching Links" "🔗"
	log_info "URL: $url"

	local html
	if ! html=$(curl -fsSL --max-time 30 -A "Mozilla/5.0 (link-extractor)" "$url" 2>/dev/null); then
		log_error "Failed to fetch: $url"
		json_output "$(json_obj_raw \
			"url" "$(json_escape "$url")" \
			"count" "0" \
			"links" "[]" \
			"error" "$(json_escape "fetch failed")")"
		return 1
	fi

	# Extract href values from <a> tags (handles single and double quotes)
	local -a raw_hrefs=()
	while IFS= read -r href; do
		[[ -n "$href" ]] && raw_hrefs+=("$href")
	done < <(printf '%s' "$html" |
		grep -oiE '<a[^>]+href[[:space:]]*=[[:space:]]*("[^"]*"|'\''[^'\'']*'\'')' |
		sed -E 's/.*href[[:space:]]*=[[:space:]]*//; s/^["'\'']//; s/["'\'']$//')

	local host="${url#*://}"
	host="${host%%/*}"

	local -a seen=()
	local -a links=()
	for href in "${raw_hrefs[@]}"; do
		local abs
		abs=$(resolve_url "$href" "$url")
		[[ -z "$abs" ]] && continue

		# Filter internal/external
		local link_host="${abs#*://}"
		link_host="${link_host%%/*}"
		if [[ "$filter" == "internal" && "$link_host" != "$host" ]]; then
			continue
		fi
		if [[ "$filter" == "external" && "$link_host" == "$host" ]]; then
			continue
		fi

		# Deduplicate
		local dup=false
		for s in "${seen[@]}"; do
			if [[ "$s" == "$abs" ]]; then
				dup=true
				break
			fi
		done
		[[ "$dup" == "true" ]] && continue

		seen+=("$abs")
		links+=("$abs")
	done

	log_success "Found ${#links[@]} unique link(s)"

	local links_json="[]"
	if [[ ${#links[@]} -gt 0 ]]; then
		links_json=$(json_arr "${links[@]}")
	fi

	json_output "$(json_obj_raw \
		"url" "$(json_escape "$url")" \
		"filter" "$(json_escape "$filter")" \
		"count" "${#links[@]}" \
		"links" "$links_json")"
}

main() {
	local url=""
	local filter="all"

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--help)
			cat <<'EOF' >&2
Usage: get-page-links.sh <url> [--internal | --external]

Fetch a web page and extract all unique <a href> links as minified JSON.
Relative URLs are resolved to absolute against the page URL.

Options:
  --internal   Only links on the same host as the page
  --external   Only links on a different host
  --help       Show this help

Output (stdout): {"url":...,"filter":...,"count":N,"links":[...]}
EOF
			exit 0
			;;
		--internal)
			filter="internal"
			shift
			;;
		--external)
			filter="external"
			shift
			;;
		*)
			url="$1"
			shift
			;;
		esac
	done

	if [[ -z "$url" ]]; then
		log_error "No URL provided. See --help."
		exit 1
	fi

	get_page_links "$url" "$filter"
}

main "$@"
