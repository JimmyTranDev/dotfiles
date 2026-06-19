---
name: stock-calendar
description: Generate upcoming stock events calendar for tracked tickers
agent: stock-researcher
---

Usage: /stock-calendar $ARGUMENTS

Generate an upcoming events calendar for stocks of interest. If `$ARGUMENTS` specifies tickers, use those. Otherwise, auto-detect tracked tickers from `~/Programming/JimmyTranDev/notes/stock-reports/` (each subdirectory name is a ticker).

## Workflow

1. Determine the ticker list:
   - If `$ARGUMENTS` contains ticker symbols, use those
   - Otherwise, list subdirectories in `~/Programming/JimmyTranDev/notes/stock-reports/` to get tracked tickers

2. For each ticker, fetch upcoming events in parallel from:
   - `https://finance.yahoo.com/quote/<TICKER>/` for next earnings date, ex-dividend date, dividend pay date
   - `https://finviz.com/quote.ashx?t=<TICKER>` for earnings date and any notable upcoming events
   - `https://stockanalysis.com/stocks/<TICKER>/` for IPO lockup expiry, stock split dates, conference presentations
   - If a source fails, skip it and note the gap

3. Compile events into a unified calendar sorted by date (soonest first).

## Output Structure

### CLI Output

Display a consolidated calendar table:

```
## Stock Events Calendar (as of YYYY-MM-DD)

| Date | Ticker | Event | Details |
|------|--------|-------|---------|
| YYYY-MM-DD | ASTS | Earnings | Q1 2026, Est. EPS $X |
| YYYY-MM-DD | MNTS | Ex-Dividend | $X/share |
| ... | ... | ... | ... |
```

After the table, show a per-ticker summary:

### Per-Ticker Notes

For each ticker, 1-2 sentences on the most important upcoming event and its potential impact.

### Saved File

Save the calendar to `~/Programming/JimmyTranDev/notes/stock-reports/calendar-<YYYY-MM-DD>.md` with YAML frontmatter:

```yaml
---
date: <YYYY-MM-DD>
tickers:
  - TICKER1
  - TICKER2
---
```

At the end of CLI output, print: `Calendar saved to ~/Programming/JimmyTranDev/notes/stock-reports/calendar-<YYYY-MM-DD>.md`

## Event Types to Track

- **Earnings**: date, estimated EPS, estimated revenue, before/after market
- **Dividends**: ex-dividend date, pay date, amount per share, yield
- **Conferences**: investor day, analyst day, industry conference presentations
- **Regulatory**: FDA decisions, FCC approvals, patent rulings, contract award deadlines
- **Corporate Actions**: stock splits, secondary offerings, lockup expirations, insider selling windows
- **Macro**: relevant sector events (e.g., space industry launches for ASTS, shipping indices for NORSE)

## Rules

- Only include events within the next 90 days
- If no events are found for a ticker, note "No upcoming events found" rather than omitting it
- Mark unconfirmed/estimated dates with "(est.)" suffix
- Include a disclaimer: dates may shift; verify before trading
- If a calendar file already exists for today's date, overwrite it
- After saving, commit and push: `git -C ~/Programming/JimmyTranDev/notes add -A && git -C ~/Programming/JimmyTranDev/notes commit -m "stock(calendar): events <YYYY-MM-DD>" && git -C ~/Programming/JimmyTranDev/notes push`
