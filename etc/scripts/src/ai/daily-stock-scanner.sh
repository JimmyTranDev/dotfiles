#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/common.sh"

# Defaults
PORTFOLIO_FILE="$HOME/Programming/JimmyTranDev/notes/stocks/portfolio.md"
OUTPUT_DIR="$HOME/Programming/JimmyTranDev/notes/stocks"
MAX_RESULTS=20
SPIKE_THRESHOLD=100  # percent increase to qualify as a spike

show_help() {
	cat <<'EOF'
Usage: daily-stock-scanner.sh [options]

Fetch trending stocks from ApeWisdom and StockTwits, filter against your
portfolio, and write a dated markdown summary.

OPTIONS:
  --portfolio FILE   Path to portfolio markdown file (default: ~/Programming/JimmyTranDev/notes/stocks/portfolio.md)
  --output DIR       Directory for output files (default: ~/Programming/JimmyTranDev/notes/stocks)
  --max NUM          Max results per category (default: 20)
  --threshold PCT    Spike threshold percentage (default: 100)
  -h, --help         Show this help

PORTFOLIO FORMAT:
  The portfolio file should contain ticker symbols as $TICKER or in a
  markdown table with a "Ticker" column. One ticker per line is also accepted.

OUTPUT:
  Writes to <output-dir>/YYYY-MM-DD.md with trending and spike tables.
  Also outputs minified JSON summary to stdout.
EOF
}

parse_portfolio() {
	local file="$1"

	if [[ ! -f "$file" ]]; then
		log_warning "Portfolio file not found: $file" >&2
		echo ""
		return
	fi

	# Extract tickers: $AAPL format or lines that are just a ticker (2-5 uppercase chars)
	{
		grep -oE '\$[A-Z]{2,5}' "$file" 2>/dev/null | sed 's/\$//'
		grep -E '^\s*[A-Z]{2,5}\s*$' "$file" 2>/dev/null | tr -d ' '
	} | sort -u
}

fetch_apewisdom() {
	log_info "Fetching ApeWisdom trending..." >&2

	local response
	response=$(curl -s --max-time 15 "https://apewisdom.io/api/v1.0/filter/all-stocks/" 2>/dev/null) || {
		log_warning "ApeWisdom API failed" >&2
		echo "[]"
		return
	}

	if ! echo "$response" | jq -e '.results' &>/dev/null; then
		log_warning "ApeWisdom returned unexpected format" >&2
		echo "[]"
		return
	fi

	echo "$response" | jq -c '[.results[:50] | .[] | {
		ticker: .ticker,
		name: .name,
		mentions: .mentions,
		rank: .rank,
		mentions_24h_ago: .mentions_24h_ago,
		source: "ApeWisdom"
	}]'
}

fetch_stocktwits() {
	log_info "Fetching StockTwits trending..." >&2

	local response
	response=$(curl -s --max-time 15 "https://api.stocktwits.com/api/2/trending/symbols.json" 2>/dev/null) || {
		log_warning "StockTwits API failed" >&2
		echo "[]"
		return
	}

	if ! echo "$response" | jq -e '.symbols' &>/dev/null; then
		log_warning "StockTwits returned unexpected format" >&2
		echo "[]"
		return
	fi

	echo "$response" | jq -c '[.symbols[:30] | .[] | {
		ticker: .symbol,
		name: .title,
		watchlist_count: .watchlist_count,
		source: "StockTwits"
	}]'
}

filter_and_rank() {
	local apewisdom_data="$1"
	local stocktwits_data="$2"
	local portfolio_tickers="$3"
	local max="$4"
	local threshold="$5"

	# Build jq filter for portfolio exclusion
	local portfolio_filter=""
	if [[ -n "$portfolio_tickers" ]]; then
		portfolio_filter=$(echo "$portfolio_tickers" | jq -Rsc 'split("\n") | map(select(length > 0))')
	else
		portfolio_filter="[]"
	fi

	# Trending: top by mentions, excluding portfolio
	local trending
	trending=$(echo "$apewisdom_data" | jq -c --argjson portfolio "$portfolio_filter" --argjson max "$max" '
		[.[] | select(.ticker as $t | ($portfolio | index($t)) | not)]
		| sort_by(-.mentions)
		| .[:$max]
	')

	# Spikes: high 24h change percentage
	local spikes
	spikes=$(echo "$apewisdom_data" | jq -c --argjson portfolio "$portfolio_filter" --argjson max "$max" --argjson threshold "$threshold" '
		[.[] | select(.ticker as $t | ($portfolio | index($t)) | not)
			| select(.mentions_24h_ago != null and .mentions_24h_ago > 0)
			| . + {change_pct: (((.mentions - .mentions_24h_ago) / .mentions_24h_ago) * 100 | round)}
			| select(.change_pct >= $threshold)]
		| sort_by(-.change_pct)
		| .[:$max]
	')

	# StockTwits trending, excluding portfolio
	local st_trending
	st_trending=$(echo "$stocktwits_data" | jq -c --argjson portfolio "$portfolio_filter" --argjson max "$max" '
		[.[] | select(.ticker as $t | ($portfolio | index($t)) | not)]
		| .[:$max]
	')

	echo "$trending"
	echo "$spikes"
	echo "$st_trending"
}

write_markdown() {
	local output_file="$1"
	local trending="$2"
	local spikes="$3"
	local st_trending="$4"
	local date="$5"

	mkdir -p "$(dirname "$output_file")"

	{
		echo "# Stock Scanner - $date"
		echo ""
		echo "## Trending (ApeWisdom - high mentions, not in portfolio)"
		echo ""
		echo "| Ticker | Name | Mentions | Rank |"
		echo "|--------|------|----------|------|"
		echo "$trending" | jq -r '.[] | "| \(.ticker) | \(.name // "-") | \(.mentions) | \(.rank) |"'
		echo ""
		echo "## Sentiment Spikes (>=${SPIKE_THRESHOLD}% increase in 24h)"
		echo ""
		echo "| Ticker | Name | Mentions | 24h Change |"
		echo "|--------|------|----------|------------|"
		echo "$spikes" | jq -r '.[] | "| \(.ticker) | \(.name // "-") | \(.mentions) | +\(.change_pct)% |"'
		echo ""
		echo "## StockTwits Trending (not in portfolio)"
		echo ""
		echo "| Ticker | Name | Watchlist Count |"
		echo "|--------|------|-----------------|"
		echo "$st_trending" | jq -r '.[] | "| \(.ticker) | \(.name // "-") | \(.watchlist_count // "-") |"'
	} > "$output_file"
}

main() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--portfolio) PORTFOLIO_FILE="$2"; shift 2 ;;
		--output) OUTPUT_DIR="$2"; shift 2 ;;
		--max) MAX_RESULTS="$2"; shift 2 ;;
		--threshold) SPIKE_THRESHOLD="$2"; shift 2 ;;
		-h | --help) show_help; exit 0 ;;
		*) log_error "Unknown option: $1"; show_help; exit 1 ;;
		esac
	done

	local today
	today=$(date +%Y-%m-%d)
	local output_file="$OUTPUT_DIR/$today.md"

	log_header "Daily Stock Scanner - $today" >&2

	# Parse portfolio
	local portfolio_tickers
	portfolio_tickers=$(parse_portfolio "$PORTFOLIO_FILE")
	local portfolio_count
	portfolio_count=$(echo "$portfolio_tickers" | grep -c . 2>/dev/null || echo "0")
	log_info "Portfolio: $portfolio_count tickers loaded" >&2

	# Fetch data from sources
	local apewisdom_data stocktwits_data
	apewisdom_data=$(fetch_apewisdom)
	stocktwits_data=$(fetch_stocktwits)

	# Filter and rank
	local trending spikes st_trending
	{
		read -r trending
		read -r spikes
		read -r st_trending
	} < <(filter_and_rank "$apewisdom_data" "$stocktwits_data" "$portfolio_tickers" "$MAX_RESULTS" "$SPIKE_THRESHOLD")

	# Fallback to empty arrays if parsing failed
	trending="${trending:-[]}"
	spikes="${spikes:-[]}"
	st_trending="${st_trending:-[]}"

	# Write output
	write_markdown "$output_file" "$trending" "$spikes" "$st_trending" "$today"
	log_success "Written to: $output_file" >&2

	# JSON summary to stdout
	local trending_count spikes_count st_count
	trending_count=$(echo "$trending" | jq 'length')
	spikes_count=$(echo "$spikes" | jq 'length')
	st_count=$(echo "$st_trending" | jq 'length')

	json_output "$(json_obj_raw \
		"date" "$(json_escape "$today")" \
		"output_file" "$(json_escape "$output_file")" \
		"trending_count" "$trending_count" \
		"spikes_count" "$spikes_count" \
		"stocktwits_count" "$st_count" \
		"portfolio_excluded" "$portfolio_count")"
}

main "$@"
