---
todoist: https://app.todoist.com/app/section/dotfiles-6f29Fcgcv4993gQG
---

# Review & PR Workflow Improvements

## Overview

Improve the reviewer agent/command and PR comment handling to be more thorough, interactive, and natural. This covers: reviewer checking more things, review defaulting to last commit, interactive review actions, PR fix comments being more natural/varied, and offering 3 comment answer suggestions.

## Architecture

Modifications to existing files:
- `src/opencode/command/review.md` — add default last-commit behavior and interactive action selection
- `src/opencode/agent/reviewer.md` — expand review checklist significantly
- `src/opencode/command/triage-comments.md` — improve comment response generation

## Data flow

1. `/review` (no args) → detects last commit → shows diff → runs review → presents interactive menu (fix, clarify, ignore, explain)
2. PR comment fixing → generates 3 varied response options → user picks one → posts selected response
3. Reviewer agent → loads all relevant review skills → applies comprehensive checklist → outputs categorized findings

## Tasks

| # | File | Change | Complexity | Parallel? |
|---|------|--------|------------|-----------|
| 1 | `src/opencode/agent/reviewer.md` | Expand — add comprehensive review categories: security, performance, error handling, naming, testability, accessibility, API design, concurrency, data validation, logging, configuration | large | yes |
| 2 | `src/opencode/command/review.md` | Modify — when no args given, default to reviewing last commit diff. After review, present interactive menu: "Fix", "Clarify (ask author)", "Ignore", "Explain reasoning" | medium | depends on understanding current review.md |
| 3 | `src/opencode/command/triage-comments.md` | Modify — generate 3 varied response suggestions per comment (formal, casual, concise). User selects which to post. Responses should feel personal and natural, not templated | medium | yes |
| 4 | `src/opencode/command/fix-pr.md` or relevant PR fix command | Modify — make generated PR fix comments more personal, natural, and varying in tone. Avoid repetitive phrasing patterns | medium | yes |

## API contracts

Review interactive menu options:
- Fix → launches fixer agent on the finding
- Clarify → generates a question to ask the code author
- Ignore → marks finding as accepted, moves to next
- Explain → shows detailed reasoning for the finding

Comment suggestion format:
```
1. [Formal] "Thank you for the feedback. I've addressed this by..."
2. [Casual] "Good catch! Fixed it — moved the validation to..."  
3. [Concise] "Fixed in abc123."
```

## State changes

No new files — all modifications to existing commands/agents.

## Edge cases

- Review with no commits on branch (fresh branch) — should fall back to showing staged changes or error gracefully
- Comment suggestions for complex technical discussions — need enough context to generate meaningful responses
- Multiple review findings — interactive menu should allow batch operations (fix all, ignore all low-severity)

## Testing approach

- Test `/review` with no args on a branch with recent commits
- Test comment suggestion variety — run multiple times and verify responses differ
- Test reviewer catches issues it previously missed

## Open questions

### Decisions
- Q1: Decision: Downgraded to p3 priority — skip interactive "Fix" action for now
- Q2: Decision: Fixed format — always formal/casual/concise as the 3 options
- Q3: Decision: Agent + all review skills (review-backend, review-frontend, review-mobile)
