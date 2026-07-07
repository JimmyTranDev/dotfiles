---
name: github-pr-description
description: Writes a clear, reviewer-focused GitHub pull request title and body — the `gh pr create --title/--body` content — grounded in the branch's actual diff, commits, spec, and verification results. Use when opening or updating a GitHub PR, writing the `--body` for `gh pr create`, filling a repo PULL_REQUEST_TEMPLATE, or fixing a thin or overstuffed PR description. Triggers on "PR description", "pull request description", "write the PR body", "describe this PR", "gh pr create body", "fill the PR template". Use ONLY for authoring your own PR's description — for a commit message use `commit`, for reviewing someone else's PR use `review-pr`/`code-review-and-quality`, for branching/history strategy use `git-workflow-and-versioning`.
---

# GitHub PR Description

## Overview

Turns a finished branch into a PR **title** and **body** a reviewer can understand without reverse-engineering the diff. The description reports what actually changed and how it was verified — facts, not intentions. For the commit messages inside the branch use `commit`; for branching and history strategy use `git-workflow-and-versioning`; this skill is the repeatable routine for the PR's own title + body.

## When to Use

- Opening a PR with `gh pr create` and you need the `--title` / `--body`.
- Updating or improving an existing PR description (thin, stale, or a raw file dump).
- Filling a repository `PULL_REQUEST_TEMPLATE.md`.
- Producing the PR body for the `/implement-pr` / `/implement-worktree` Phase 6.

**Do NOT use when:**

- Writing a commit message — use `commit`.
- Reviewing or critiquing someone else's PR — use `review-pr` / `code-review-and-quality`.
- Choosing a branching strategy or commit granularity — use `git-workflow-and-versioning`.
- The change isn't built and verified yet — write the description from real results, not plans.

## Gather the Material First

A good description reports facts, so collect them before writing:

- **The diff:** `git diff <base>...HEAD --stat`, then the full `git diff <base>...HEAD` (three-dot = only what this branch added since it diverged from the base).
- **The commits:** `git log <base>..HEAD --oneline` — the narrative is often already there.
- **The intent:** the spec, Jira ticket, or issue this addresses (and its acceptance criteria).
- **The verification:** the test / build / lint / coverage results you actually ran.
- **Base + head branch:** for the title and `gh pr create --base <base>`.

## Title Format

One line, imperative, no trailing period — it becomes the squash-merge commit
subject. There is **one** canonical shape, identical to `commit`'s, so titles
never drift:

```
<type>[(scope)]: [<KEY> ]<summary>
```

```
feat: BW-10497 create credit-card success page   # with a Jira key
feat: add credit-card success page               # no ticket
fix(auth): reject expired refresh tokens          # optional scope, no ticket
fix(auth): BW-10231 reject expired refresh tokens # optional scope + ticket
```

Rules — all mandatory, in this exact order:

- **Type first, always.** Start with a Conventional Commit type from `commit`
  (`feat`, `fix`, `refactor`, `perf`, `docs`, `style`, `test`, `build`, `ci`,
  `chore`, `revert`). Never start a title with a bare Jira key.
- **Jira key bare, right after the colon**, matching `[A-Z]+-[0-9]+` — no
  brackets, no parentheses. `feat: BW-10618 …`, never `feat: [BW-10618] …`,
  `feat(BW-10618): …`, or `… (BW-10618)`. The scope slot `(…)` is for a real
  code area (`auth`, `api`), never the ticket.
- **Lowercase imperative summary** after the key: `create car page`, not
  `Create car page`. Describe the change, not the files ("add retry to webhook
  sender", not "update sender.ts").
- Keep it ≤~70 chars.

### Do / don't (from real drift)

| Don't | Do |
|---|---|
| `[BW-10618] Create Car page (refinance)` | `feat: BW-10618 create refinance car page` |
| `feat: [BW-10620] create refinance repayment period page` | `feat: BW-10620 create refinance repayment period page` |
| `feat(BW-10616): create child support page` | `feat: BW-10616 create child support page` |
| `feat(refinance): [BW-10615] render children page` | `feat: BW-10615 render refinance children page` |
| `BW-10593 Create refinance introduction page` | `feat: BW-10593 create refinance introduction page` |
| `feat: add current-loan page to refinance flow (BW-10605)` | `feat: BW-10605 add current-loan page to refinance flow` |

## Body Template

GitHub-flavored markdown. Keep the sections that carry signal and drop the ones that don't apply — never ship an empty heading.

```markdown
## Summary
<1–3 sentences: what this PR does and why. The reviewer reads this first.>

## What changed
- <substantive change in reviewer terms — behavior, not filenames>
- <…>

## Why
<Motivation / context. Link the source of truth:>
Closes #123   ·   Jira: https://storebrand.atlassian.net/browse/BW-10497

## How it was verified
- Tests: <`npm test` → 42 passing, +3 new>
- Build / lint / types: <result>
- Manual: <steps you actually ran>

## Screenshots / demo
<Before/after for any user-visible change. Omit for non-UI PRs.>

## Breaking changes
<What breaks + the migration path. Omit when none.>

## Notes for reviewers
- <Where to start, risky areas, deliberate trade-offs>
- Out of scope / follow-ups: <what you intentionally left untouched>
```

### Section Rules

- **Summary** is mandatory; lead with the user-visible outcome.
- **What changed** is a digest of behavior, not `git diff --name-only`. Group related edits; skip mechanical noise (formatting, renames) or label it as such.
- **Why** links issues with closing keywords (`Closes` / `Fixes` / `Resolves #N`) so the merge auto-closes them; add the Jira URL when a key exists.
- **How it was verified** records what you actually ran. If you didn't run it, say so — never imply coverage you don't have.
- When the repo has a `PULL_REQUEST_TEMPLATE.md`, fill its sections instead of imposing this layout.

## The Workflow

1. **Gather** the diff, commits, intent, and verification results (above).
2. **Draft the title** from the dominant change (or `<KEY> <summary>` for a Jira ticket).
3. **Write the body** from the template, keeping only the sections that carry signal; honor any repo PR template.
4. **Read it as the reviewer would:** can they grasp intent and risk without opening the diff? Trim anything that merely restates the diff.
5. **Verify honesty:** every claimed test/build result is real, every issue/Jira link resolves, scope is not overstated.
6. **Hand off** the title + body (e.g. `gh pr create --base <base> --title "…" --body "…"`). Opening the PR is the caller's job, not this skill's.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The diff explains itself." | The diff shows *what*, never *why*. Reviewers need intent and risk up front. |
| "I'll list every changed file." | A file dump is `--name-only`, not a description. Summarize behavior, not paths. |
| "I'll say 'tested locally' so it looks thorough." | Claiming unrun verification misleads the reviewer. Report only what you actually ran. |
| "I'll reuse the Jira summary verbatim." | The ticket states the goal, not the change. Describe what this PR actually did. |
| "Closing keywords are optional." | `Closes #N` auto-closes the issue on merge and links the trail. Use it. |
| "Every template heading must stay." | Empty sections add noise. Drop the ones that don't apply (keep a repo template's required ones). |
| "I'll bracket the ticket / lead with the key — it reads fine." | The title is a squash-merge commit subject; `[BW-X]`, `(BW-X):`, trailing `(BW-X)`, and a bare leading `BW-X` all break the one `<type>: <KEY> <summary>` form. Type first, key bare after the colon. |

## Red Flags

- Body is a single line, or just the branch name / Jira title.
- "What changed" is a list of file paths.
- A verification claim for something you never ran.
- Empty template headings shipped with no content.
- A user-visible change with no screenshot.
- A linked issue/Jira that 404s, or a closing keyword pointing at the wrong number.
- A title that names files ("update X.ts") instead of the change.
- A title led by a bare Jira key, a bracketed `[BW-X]`, a `(BW-X):` scope-key, or a trailing `(BW-X)` instead of `<type>: <KEY> <summary>`.
- A capitalized summary (`Create car page`) instead of lowercase imperative.

## Verification

- [ ] Title is one imperative line matching `<type>[(scope)]: [<KEY> ]<summary>` — valid Conventional Commit type first, Jira key (if any) bare right after the colon (no `[]`/`()`), lowercase summary, no trailing period.
- [ ] Summary states what + why in ≤3 sentences.
- [ ] "What changed" describes behavior, not filenames.
- [ ] Every verification claim corresponds to a result actually produced.
- [ ] Issues linked with closing keywords; Jira URL present when a key exists; all links resolve.
- [ ] No empty sections; an existing repo PR template's required sections are filled.
- [ ] Body is GitHub-flavored markdown that renders cleanly.
