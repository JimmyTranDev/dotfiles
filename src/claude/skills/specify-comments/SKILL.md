---
name: specify-comments
description: Specify skill for PR review comments — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`comments-` (followed by PR number and branch name, e.g., `comments-pr-123-feature-branch`)

## Skills to Load

None required.

## Agents to Launch

None required.

## Analysis Categories

### Comment Fetching

Run `fetch-pr-comments.sh` to fetch PR review comments as JSON (unresolved
inline + PR-level by default). Pass `--resolved` to include resolved threads.
Consume its JSON instead of re-deriving the `gh` calls:

```bash
fetch-pr-comments.sh [PR]          # unresolved inline + PR-level comments
fetch-pr-comments.sh --resolved    # include resolved threads
```

To skip your own comments, get the current user with `gh api user --jq '.login'`
and filter the script's output by author.

### Comment Filtering

- Skip comments authored by the current user
- Skip pure praise, acknowledgments, approvals, or automated bot messages
- Skip replies that don't contain a distinct change request

### Comment Classification

- **Change request**: Requests a specific code change
- **Question/concern**: Raises an issue but doesn't specify an exact change
- **Suggestion**: Optional improvement, not blocking

### Presentation (per comment)

- **File & location**: Path and line number
- **Author**: Who left the comment
- **What they said**: Original comment text (brief quote)
- **What they're asking for**: Plain-language explanation of what the reviewer wants
- **Thread context**: Summary of follow-up discussion progression

### Summary

- Total unresolved comments count
- Group by theme (naming concerns, error handling gaps, performance suggestions, logic issues)
- Flag blocking vs. nice-to-have based on tone
- For change requests, include concrete description of code change needed

## Severity Classification

- **Blocking**: Change requests with strong language or explicit blocking reviews
- **Important**: Questions/concerns that suggest bugs or design issues
- **Nice-to-have**: Optional suggestions and style preferences

## Scope Overrides

Scope is always the current branch's PR. If no PR exists, notify and stop.
