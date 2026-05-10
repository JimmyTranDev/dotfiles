---
name: research-stock
description: Research a stock ticker with fundamentals, technicals, peer comparison, and timeframe-based ratings
agent: stock-researcher
---

Usage: /research-stock $ARGUMENTS

$ARGUMENTS

Research the given stock ticker(s) and produce a comprehensive buy/sell analysis report. If multiple tickers are provided, produce individual reports followed by a comparison table.

## Output Structure

The report is produced in two tiers:

**Tier 1 (CLI output)**: Executive Summary, Ratings Summary, What to Watch, Bottom Line. This is what the user sees immediately in the terminal.

**Tier 2 (saved file)**: The full report with all sections. Saved as a plain markdown file to `~/Programming/JimmyTranDev/notes/stock-reports/<TICKER>/<YYYY-MM-DD>.md`. Create the directories if they don't exist.

The saved file includes YAML frontmatter:
```yaml
---
ticker: <TICKER>
date: <YYYY-MM-DD>
verdict: <Strong Buy|Buy|Hold|Sell|Strong Sell>
short_term_rating: <X/10>
long_term_rating: <X/10>
---
```

At the end of the CLI output, print: `Full report saved to ~/Programming/JimmyTranDev/notes/stock-reports/<TICKER>/<YYYY-MM-DD>.md`

If a saved report already exists for the same ticker (any previous date in `~/Programming/JimmyTranDev/notes/stock-reports/<TICKER>/`), include a "Changes Since Last Report" section showing price change, any rating categories that moved by 2+ points, and new catalysts.

## Workflow

1. Parse `$ARGUMENTS` for ticker symbol(s). If none found, ask the user which stock(s) to analyze. If multiple tickers are provided (e.g., `ASTS RKLB`), analyze each individually then produce a comparison section at the end.

2. Fetch data from multiple sources in parallel for each ticker:
   - `https://finance.yahoo.com/quote/<TICKER>/` for price, market cap, PE, EPS, volume, 52-week range, earnings date, analyst targets
   - `https://finviz.com/quote.ashx?t=<TICKER>` for technicals (RSI, SMAs, short float, beta, ATR), financials (margins, ROE, debt), analyst ratings, and institutional/insider ownership
   - `https://stockanalysis.com/stocks/<TICKER>/financials/` as a fallback for revenue, earnings, and balance sheet data
   - `https://stocktwits.com/symbol/<TICKER>` for retail sentiment (bullish/bearish ratio, message volume, trending status)
   - If a primary source fails, note the failure and rely on the remaining sources

3. Compile the report with these sections per ticker:

### Executive Summary (Tier 1 — CLI)

Show this first in CLI output. Contains:
- **Verdict**: Strong Buy / Buy / Hold / Sell / Strong Sell (derived from overall ratings)
- **1-sentence thesis**: the core reason to buy or avoid
- **Key metrics table**:

| Metric | Value |
|--------|-------|
| Price | $X |
| Market Cap | $X |
| P/E | X |
| Revenue Growth YoY | X% ↑/↓ |
| RSI(14) | X |
| Short-Term Rating | X/10 [LABEL] |
| Long-Term Rating | X/10 [LABEL] |
| Entry Zone | $X - $X |
| Stop Loss | $X |

### Price Snapshot
Table with: last close, previous close, day's range, 52-week range, market cap, avg volume, relative volume

### Fundamental Analysis

Group into sub-tables for scannability:

**Valuation**

| Metric | Value |
|--------|-------|
| P/E | |
| Forward P/E | |
| P/S | |
| P/B | |
| PEG | |
| EV/EBITDA | |

**Profitability**

| Metric | Value |
|--------|-------|
| Gross Margin | |
| Operating Margin | |
| Profit Margin | |
| ROE | |
| ROA | |
| ROIC | |

**Growth**

| Metric | Value |
|--------|-------|
| Revenue | |
| Net Income | |
| EPS | |
| Revenue Growth YoY | ↑/↓ |
| EPS Growth YoY | ↑/↓ |

**Health**

| Metric | Value |
|--------|-------|
| Debt/Equity | |
| Cash Position | |

### Sector & Peer Comparison
Identify 3-5 closest peers by market cap and sector. Table comparing:

| Metric | <TICKER> | Peer 1 | Peer 2 | Peer 3 |
|--------|----------|--------|--------|--------|
| Market Cap | | | | |
| P/E | | | | |
| P/S | | | | |
| Revenue Growth | | | | |
| Profit Margin | | | | |
| 1Y Return | | | | |

Include a sentence on whether the stock is overvalued/undervalued relative to peers.

### Technical Analysis
Table with: RSI(14), SMA 20/50/200 (% above/below and trend direction using ↑/↓/→), MACD signal (bullish/bearish crossover), beta, ATR(14), relative volume, short float, short ratio.

Provide a technical verdict paragraph interpreting the signals together. Identify key support and resistance levels from the 52-week range and SMA levels.

### Ownership & Flow
Table with:
- Institutional ownership %
- Insider ownership %
- Insider transactions (net buy/sell last 3 months)
- Short float % and short ratio
- Recent notable institutional buyers/sellers if available from the data

### Catalyst Calendar
Upcoming earnings date and expected EPS/revenue, recent news events (last 30 days), regulatory milestones, competitive developments, upcoming product launches or contract announcements

### Analyst & Retail Sentiment
Average/low/high price targets, recommendation distribution (strong buy/buy/hold/underperform/sell), recent rating changes with dates and price target changes. Note the trend direction (upgrades ↑ vs downgrades ↓ over last 6 months).

Stocktwits sentiment: bullish/bearish ratio, message volume (high/normal/low), whether the ticker is trending, and any notable sentiment shifts (e.g., "sentiment flipped bearish in last 48 hours").

### Bull Case
3-5 bullet points supporting a buy thesis

### Bear Case
3-5 bullet points supporting a sell/avoid thesis

### Ratings Summary (Tier 1 — CLI)

Rate each category for both short-term (1-3 months) and long-term (1-3 years). Prefix each rating with a label:
- 8-10: `[STRONG]`
- 6-7: `[OK]`
- 4-5: `[WEAK]`
- 1-3: `[DANGER]`

| Category | Short-Term (1-3mo) | Long-Term (1-3yr) | Notes |
|----------|-------------------|-------------------|-------|
| Valuation | [LABEL] X/10 | [LABEL] X/10 | |
| Growth | [LABEL] X/10 | [LABEL] X/10 | |
| Profitability | [LABEL] X/10 | [LABEL] X/10 | |
| Balance Sheet | [LABEL] X/10 | [LABEL] X/10 | |
| Technical Setup | [LABEL] X/10 | [LABEL] X/10 | |
| Momentum | [LABEL] X/10 | [LABEL] X/10 | |
| Catalyst Risk | [LABEL] X/10 | [LABEL] X/10 | |
| Competition Risk | [LABEL] X/10 | [LABEL] X/10 | |
| Short Squeeze Potential | [LABEL] X/10 | -- | |
| **Overall** | **[LABEL] X/10** | **[LABEL] X/10** | |

### Position Sizing & Risk Management
Based on the analysis, provide:
- **Entry zone**: price range where risk/reward is favorable
- **Stop loss level**: technical level where the thesis is invalidated (based on key support)
- **Take profit targets**: 2-3 price targets with rationale
- **Suggested position size**: as a % of portfolio based on conviction and volatility (use ATR and beta to calibrate -- higher volatility = smaller position)
- **Risk/reward ratio**: calculated from entry, stop, and first target

### What to Watch (Tier 1 — CLI)

3-5 specific, actionable trigger conditions the user should monitor:
- "Buy if: price pulls back to $X (SMA 50 support) with RSI < 30"
- "Sell if: breaks below $X (SMA 200) on high volume"
- "Watch for: earnings on DATE, consensus EPS $X vs whisper $X"
- "Alert: short interest at X% -- squeeze potential if price breaks $X"
- "Re-evaluate if: revenue growth decelerates below X% next quarter"

### Bottom Line (Tier 1 — CLI)
2-3 sentences with actionable guidance for aggressive traders, long-term investors, and current holders.

### Changes Since Last Report

Only include this section if a previous report exists for this ticker in `~/Programming/JimmyTranDev/notes/stock-reports/<TICKER>/`. Show:
- Price change since last report ($ and %)
- Any rating categories that moved by 2+ points (with direction ↑/↓)
- New catalysts or events since the last report date
- Whether the overall verdict changed

## Trend Indicators

Use directional indicators throughout the report for any metric that has a trend:
- Rising/bullish: `↑`
- Falling/bearish: `↓`
- Flat/neutral: `→`

Apply to: SMA trend directions, revenue/EPS growth, analyst target changes, sentiment shifts, insider transaction trends.

## Multi-Ticker Comparison

When multiple tickers are analyzed, add a final section after all individual reports:

### Head-to-Head Comparison

| Metric | TICKER1 | TICKER2 | ... |
|--------|---------|---------|-----|
| Price | | | |
| Market Cap | | | |
| P/S | | | |
| Revenue Growth | | | |
| Short-Term Rating | [LABEL] X/10 | [LABEL] X/10 | |
| Long-Term Rating | [LABEL] X/10 | [LABEL] X/10 | |
| Risk/Reward | | | |

End with a verdict: which stock is the better buy right now and why, and which is better for long-term holding.

For multi-ticker runs, save individual report files per ticker (each in their own `<TICKER>/` subdirectory). The comparison table is shown in CLI output only.

## Rules

- Always include a disclaimer: this is informational analysis, not financial advice
- If data sources fail or return incomplete data, note which metrics are missing rather than guessing
- Use the most recent available data -- do not fabricate numbers
- Rate honestly -- a 4/10 is a 4/10, do not inflate ratings
- For pre-revenue or speculative companies, weight growth potential and cash runway higher than profitability metrics
- Short-term ratings should weigh technicals and catalysts more heavily
- Long-term ratings should weigh fundamentals, competitive moat, and growth trajectory more heavily
- Position sizing suggestions should be conservative -- never suggest more than 5% of portfolio for speculative stocks
- If a previous report exists for the same ticker but data cannot be compared meaningfully, skip the "Changes Since Last Report" section
- If repeat analysis is run on the same day, overwrite the existing file (same date = same filename)
- After saving the report, commit and push the notes repo: `git -C ~/Programming/JimmyTranDev/notes add -A && git -C ~/Programming/JimmyTranDev/notes commit -m "stock(<TICKER>): report <YYYY-MM-DD>" && git -C ~/Programming/JimmyTranDev/notes push`
