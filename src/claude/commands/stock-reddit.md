---
description: Summarize today's top posts from investment-related subreddits
argument-hint: $ARGUMENTS
---

Usage: /stock-reddit $ARGUMENTS

Fetch and summarize today's top/hot posts from the following subreddits, grouped by category.

## Subreddits

**Core Holdings**:
- /r/ASTSpaceMobile
- /r/BlackskyTechnology
- /r/FLY_STOCK
- /r/IntuitiveMachines
- /r/PlanetLabs
- /r/redwire
- /r/RKLB
- /r/sellaslifesciences

**General / Discovery**:
- /r/biotech_stocks
- /r/pennystocks
- /r/SpaceInvestorsDaily
- /r/wallstreetbets

## Workflow

1. For each subreddit, fetch `https://www.reddit.com/r/<subreddit>/hot.json?limit=10&t=day` (use WebFetch with the `.json` suffix to get structured data). Run all fetches in parallel.

2. Filter posts to only those from today (based on `created_utc`). If `$ARGUMENTS` contains a date like `yesterday` or a specific date, use that instead.

3. For each subreddit that has posts, produce a summary section:

### /r/<subreddit> (X posts today)

For each post:
- **Title** (score | comments) — 1-2 sentence summary of the content/discussion
- Flag posts with high engagement (>50 upvotes or >20 comments) with `[HOT]`
- Note any price targets, catalysts, or sentiment shifts mentioned

4. After all subreddits, produce a **Key Takeaways** section:
   - Aggregate sentiment per ticker mentioned (bullish/bearish/mixed)
   - Notable catalysts or news across all subs
   - Any tickers getting unusual attention

## Output

Print the full summary to the terminal. Also save to `~/Programming/JimmyTranDev/notes/reddit-summaries/<YYYY-MM-DD>.md`. Create directories if needed.

After saving, commit and push: `git -C ~/Programming/JimmyTranDev/notes add -A && git -C ~/Programming/JimmyTranDev/notes commit -m "reddit: daily summary <YYYY-MM-DD>" && git -C ~/Programming/JimmyTranDev/notes push`

## Rules

- If a subreddit returns no posts for today, note it as "No activity today" and move on
- If a fetch fails, note the error and continue with remaining subs
- Do not editorialize beyond summarizing what was posted
- If `$ARGUMENTS` specifies specific subreddits (e.g., `/reddit-summary RKLB ASTS`), only fetch those
