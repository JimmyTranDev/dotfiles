---
todoist:
  - https://app.todoist.com/app/task/create-some-commands-for-finding-new-hot-stocks-or-sectors-6gvC6HR2wC6qXM8F
  - https://app.todoist.com/app/task/create-a-stock-focus-list-so-that-it-researches-all-of-them-6gvC7p2c373r6XrF
  - https://app.todoist.com/app/task/create-frontend-for-stock-research-6gvC7rqPMG6Q8R3F
---

# Devtools: Stock Research Suite

> **Layer recommendation:** Mixed. #13 and #14 are backend/CLI (opencode commands + a config file in dotfiles). #15 is a separate frontend application that does **not** belong in the dotfiles repo — it is captured here for completeness but must be implemented in its own repo.

## TL;DR
- Covers 3 p1 tasks: commands to discover hot stocks/sectors, a focus-list config the research reads, and a frontend for stock research.
- #13 + #14 live in dotfiles (`src/opencode/command/` + a new config file) and reuse the existing `stock-researcher` agent and `stock-*` commands.
- #15 (frontend) is cross-repo — needs its own project; this spec only records requirements and open questions for it.
- Most critical: the focus-list config (#14) is the shared dependency both the discovery commands and research consume.
- Estimated effort: ~half a day for #13/#14 in dotfiles; #15 is a separate project sized elsewhere.

## Overview
Extend the existing stock-research tooling. Add command(s) that surface newly "hot" stocks or sectors, introduce a focus-list config so the researcher can batch-analyze a curated set, and (cross-repo) build a frontend to view research output. Discovery reuses the data sources the current `stock-*` commands already use.

## Architecture
- **Existing**: `src/opencode/agent/stock-researcher.md`; commands `stock-advisor.md`, `stock-calendar.md`, `stock-reddit.md`, `stock-research.md`. `/stock-research` already produces fundamentals/technicals/ratings via the `stock-researcher` agent.
- **New focus list**: a config file in dotfiles (format TBD — see open questions) that the discovery/research commands read to know which tickers to analyze.
- **Frontend (#15)**: a standalone app in its own repo (stack TBD) consuming the research output — out of scope for dotfiles implementation.

## Data flow
1. Discovery command (#13) queries the existing stock data sources (the same ones `stock-reddit`/`stock-advisor` use) → ranks hot stocks/sectors → optionally appends to the focus list.
2. Research reads the focus-list config (#14) → runs `stock-researcher` for each ticker → emits per-ticker reports.
3. Frontend (#15) renders the reports.

## Tasks
| # | File | Change | Complexity | Deps | Parallel? |
|---|------|--------|------------|------|-----------|
| 1 | `src/opencode/stock-focus-list.json` (new) | #14: define a focus-list config (tickers the suite researches) as a small JSON/text file in dotfiles | Small | None | Yes |
| 2 | `src/opencode/command/stock-hot.md` (new) | #13: command(s) to find new hot stocks/sectors, reusing existing stock data sources; option to add picks to the focus list | Medium | 1 | Sequential after 1 |
| 3 | `src/opencode/command/stock-research.md` (edit) | Teach `/stock-research` to accept "all from focus list" so it researches every focus-list ticker | Small | 1 | Sequential after 1 |
| 4 | (cross-repo) | #15: stock research frontend — separate app/repo; capture requirements only here | Large | 1,3 | N/A (other repo) |
| 5 | regenerate `~/.claude/` | Run `opencode-to-claude.sh` after command changes | Small | 2,3 | Sequential |

## API contracts
- **Focus list**: a simple list of tickers (+ optional metadata like target weight/notes). Consumed by `/stock-research --focus` and the discovery command.
- **#13 command output**: ranked list of tickers/sectors with the signal that flagged them (volume, social momentum, sector rotation) per the existing sources.

## State changes
- New focus-list config file in `src/opencode/`.
- Edited `/stock-research` command.
- Regenerated `~/.claude/`.

## Edge cases
- Empty focus list → `/stock-research --focus` reports nothing to do, exits cleanly.
- Discovery source unavailable/rate-limited → degrade gracefully, report partial results.
- Duplicate ticker added to focus list → dedup on insert.
- Invalid ticker in focus list → skip with a warning, continue the batch.

## Testing approach
- Run `/stock-hot` and confirm it returns a ranked list from real sources.
- Add tickers to the focus list, run `/stock-research --focus`, confirm one report per ticker.
- Cross-repo frontend testing is defined in its own repo.

## Open questions
### Architecture
- **Decision: the focus list is a small JSON/text file under `src/opencode/`** that commands read directly (e.g. `src/opencode/stock-focus-list.json`).
- **Which existing data sources feed #13?** You chose "reuse existing stock data sources" — confirm that means the sources behind `stock-reddit`/`stock-advisor`/`stock-calendar`. (Recommend: yes, compose those.) — Decision pending.
### Scope
- **#15 frontend** — which repo and stack (Next.js? Expo? existing app)? This is explicitly out of the dotfiles repo; needs its own spec there. — **Cross-repo, blocked on repo identification.**
### Risks
- Reusing scraping-based sources (Reddit/social) may be rate-limited or fragile — discovery should fail soft.

## References
- Cross-repo task (#15): https://app.todoist.com/app/task/create-frontend-for-stock-research-6gvC7rqPMG6Q8R3F
