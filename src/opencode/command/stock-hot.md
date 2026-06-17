---
name: stock-hot
description: Discover newly hot stocks and sectors by composing existing stock data sources
agent: stock-researcher
---

Usage: /stock-hot $ARGUMENTS

Surface newly "hot" stocks and sectors by composing the data sources the existing `stock-*` commands already query: the `/stock-reddit` subreddits and the Yahoo / Finviz / StockAnalysis / Stocktwits sources behind `/stock-research` and `/stock-calendar`. Rank candidates by the signal that flagged them and optionally append the top picks to the focus list. Reuse the existing sources only — never introduce a new data provider.

## Signals & Sources

Each candidate is flagged by one or more signals. Every signal reuses a source the existing `stock-*` commands already query (just a different view of it).

- **Social momentum** — the `/stock-reddit` subreddits + Stocktwits (the `/stock-research` sentiment source):
  - `https://www.reddit.com/r/<subreddit>/hot.json?limit=25&t=day` for the General / Discovery subs (`wallstreetbets`, `pennystocks`, `biotech_stocks`, `SpaceInvestorsDaily`) and the Core Holdings subs. Tally distinct ticker mentions weighted by score + comment count; flag tickers surging today. **Note:** webfetch frequently gets HTTP 403 from Reddit on *both* `www.reddit.com` and `old.reddit.com` (the `.json` endpoints and HTML alike) — when that happens, fail soft to Stocktwits-only social momentum and say so, rather than retrying Reddit endlessly.
  - `https://stocktwits.com/symbol/<TICKER>` for message-volume spikes and trending status on candidates.
- **Volume / price action** — Finviz + Yahoo (the `/stock-research` + `/stock-calendar` sources):
  - `https://finviz.com/screener.ashx?v=111&s=ta_topgainers` and `...&s=ta_unusualvolume` for unusual relative volume and top movers.
  - `https://finance.yahoo.com/quote/<TICKER>/` to confirm a candidate's day move, relative volume, and average volume.
- **Sector rotation** — Finviz groups (same Finviz source, sector view):
  - `https://finviz.com/groups.ashx?g=sector&v=140&o=-change` and `...&g=industry&...` for the sectors/industries leading on the day/week. Use **`v=140`** (Performance, exposes day/week/month change columns) or `v=110` (Overview) — **not `v=210`**, which is the charts view and returns no parseable table via webfetch.

## Workflow

1. Parse `$ARGUMENTS` for options:
   - `--append` — after ranking, append the newly-flagged stock candidates to the focus list (deduped).
   - `--append TICKER1 TICKER2 ...` — append only the named tickers (still deduped).
   - `--top N` — number of candidates to rank (default 10).
   - Any bare sector/ticker hints narrow the scan to that theme (optional).

2. Gather every signal in parallel across the sources above. **Fail soft**: if a source is rate-limited, 404s, or times out, note the gap and keep going with the remaining sources — never abort the run.

3. Build the candidate set: collect the tickers/sectors flagged by any signal, deduplicate, and tag each with which signal(s) flagged it plus the supporting evidence (relative volume, mention count, sector change %, etc.).

4. Rank: score each candidate, weighting candidates flagged by multiple independent signals highest. Sort descending and keep the top N.

5. Produce the output below, save the report, then (if requested) update the focus list.

## Output Structure

### CLI Output

Lead with a ranked table:

```
## Hot Stocks & Sectors (as of YYYY-MM-DD)

| Rank | Candidate | Type | Signal(s) | Evidence |
|------|-----------|------|-----------|----------|
| 1 | ASTS | Stock | Social + Volume | 140 WSB mentions, relvol 3.2x |
| 2 | Uranium | Sector | Rotation | +4.1% on the day, leading industries |
| ... | ... | ... | ... | ... |
```

Follow with two short subsections:

- **Sector Rotation** — the 3-5 sectors/industries leading today, with the change % and a one-line read on what is rotating in.
- **Social Momentum** — the tickers with the biggest mention/volume spikes vs a normal day, with the dominant sentiment.

Note any source that was unavailable, e.g.: `Partial results — Stocktwits rate-limited, social momentum based on Reddit only.`

### Saved File

Save the discovery report to `~/Programming/JimmyTranDev/notes/stock-reports/hot-<YYYY-MM-DD>.md` with YAML frontmatter:

```yaml
---
date: <YYYY-MM-DD>
tickers:
  - TICKER1
  - TICKER2
sectors:
  - SECTOR1
---
```

At the end of CLI output, print: `Discovery saved to ~/Programming/JimmyTranDev/notes/stock-reports/hot-<YYYY-MM-DD>.md`

After saving, commit and push the notes repo: `git -C ~/Programming/JimmyTranDev/notes add -A && git -C ~/Programming/JimmyTranDev/notes commit -m "stock(hot): discovery <YYYY-MM-DD>" && git -C ~/Programming/JimmyTranDev/notes push`

## Appending to the Focus List

Only when `--append` is passed. The focus list lives at `~/Programming/JimmyTranDev/dotfiles/src/opencode/stock-focus-list.json`:

```json
{
  "tickers": [
    { "ticker": "ASTS", "target_weight": null, "notes": "..." }
  ]
}
```

- `ticker` (required): the symbol — stored uppercase
- `target_weight` (optional number): target portfolio weight as a percent (leave `null` when unknown)
- `notes` (optional string): freeform context

Steps:
1. Read the file. If it is missing or unreadable, start from `{ "tickers": [] }`.
2. Choose what to add: the named tickers if provided, otherwise the ranked stock candidates (sectors are never added — the list holds tickers only).
3. **Dedup on insert**: skip any symbol already present in `tickers[]` (case-insensitive). Report skipped duplicates.
4. Append each new entry as `{ "ticker": "<SYM>", "target_weight": null, "notes": "<signal that flagged it> (added <YYYY-MM-DD>)" }`, preserving existing entries and order.
5. Write the file back as pretty-printed JSON (2-space indent, trailing newline).
6. Report what was added and what was skipped. Do **not** auto-commit — the focus list lives in the dotfiles repo; tell the user to commit it there.

## Field Notes

Reusable techniques learned running themed scans:

- **Themed scan with no theme hits → pivot to a curated basket.** When a bare sector/ticker hint narrows the scan but the generic `ta_topgainers` / `ta_unusualvolume` screens surface *no* names matching the theme, don't report "nothing hot." Directly screen a hand-built basket of known theme pure-plays via the Finviz multi-ticker screener: `https://finviz.com/screener.ashx?v=171&t=TICKER1,TICKER2,...` (`v=171` = technical view: % change, rel-vol, RSI, beta) and cross-check with `v=111` (overview: price, volume, market cap). This surfaces theme-specific moves a market-wide gainers list buries.
- **Basket-wide pop ≠ sector rotation — check the parent industry first.** A single-day move where a whole theme basket gaps up together is often a **relief bounce off a recent catalyst** (e.g. a sector IPO repricing the group), not money rotating into the sector. Always cross-check the parent Finviz industry/sector change %: if the basket is up high-beta double digits while its industry (e.g. Aerospace & Defense) is roughly flat, label it **idiosyncratic mean-reversion / catalyst-driven**, not rotation — and name the catalyst. Reserve the "Sector Rotation" framing for when the industry/sector group itself is actually leading the tape.

## Rules

- Reuse only the sources above (Reddit, Finviz, Yahoo, StockAnalysis, Stocktwits) — never add a new provider.
- Fail soft: a rate-limited or unavailable source degrades to partial results with a noted gap, never a hard failure.
- Dedup every focus-list insert against existing entries (case-insensitive).
- Always tag each candidate with the concrete signal and evidence that flagged it — no unsourced picks.
- This is informational discovery, not financial advice — include a one-line disclaimer.
- Do not run a full per-ticker research report here; `/stock-research --focus` handles deep analysis of the focus list.
