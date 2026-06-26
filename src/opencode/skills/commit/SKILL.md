---
name: commit
description: Creates a conventional-commit message for already-staged changes and commits them. Use when the user says "commit", "create a commit", "commit my changes", or "commit the staged files". Commits only what is already staged, derives a Jira ticket from the branch name, and never stages extra files.
---

# Commit

## Overview

Creates a well-formatted conventional commit for the changes that are **already staged**, deciding the type, scope, and description autonomously from the diff. For broader commit philosophy (atomic commits, separating concerns, descriptive messages), defer to `git-workflow-and-versioning`; this skill is the exact, repeatable routine for turning a staged diff into a commit.

## When to Use

- The user asks to "commit", "create a commit", or "commit my staged changes".
- Changes are already staged and need a properly formatted message.

**Do NOT use when:**

- Nothing is staged — notify the user and stop, do not stage files yourself.
- The user wants commit history theory or branching strategy — use `git-workflow-and-versioning`.

## Format

Follow the [Conventional Commits 1.0.0 spec](https://www.conventionalcommits.org/en/v1.0.0/#specification):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

With a Jira ticket (when the branch name contains one), place the key right
after the colon — before the description, and after the optional scope:

```
<type>[(scope)]: <TICKET> <description>
```

For example: `feat: BW-10497 create credit card success page`.

Indicate a breaking change by appending `!` before the colon (`feat(api)!: ...`)
and/or adding a `BREAKING CHANGE:` footer.

### Commit types

Auto-detect the type from the staged diff. `feat` and `fix` are mandated by the
spec; the rest follow the Angular/commitlint convention:

| Type       | When |
|------------|------|
| `feat`     | Adds a new feature (MINOR in SemVer). |
| `fix`      | Patches a bug (PATCH in SemVer). |
| `refactor` | Code change that neither fixes a bug nor adds a feature. |
| `perf`     | Improves performance. |
| `docs`     | Documentation only. |
| `style`    | Formatting/whitespace, no code-behavior change. |
| `test`     | Adds or updates tests. |
| `build`    | Build system or external dependencies. |
| `ci`       | CI configuration and scripts. |
| `chore`    | Tooling, config, or maintenance with no src/test behavior change. |
| `revert`   | Reverts a previous commit. |

If the diff fits more than one type, pick the dominant change; prefer splitting
into separate commits when concerns are genuinely distinct.

## The Workflow

1. **Verify staged content.** Run `git diff --cached --name-only`. If empty, tell the user nothing is staged and stop — do **not** stage anything.
2. **Read the staged diff.** Run `git diff --cached -- . ':!*.csv'`. Always exclude `*.csv` — those diffs are large, noisy, and unhelpful.
3. **Extract the Jira ticket.** Run `git branch --show-current`. Match the branch against `[A-Z]+-[0-9]+` (e.g. `BW-10231`, `PROJ-456`). If found, place the key right after `: ` in the message. If not, use the standard format.
4. **Decide type, scope, description.** Choose autonomously from the diff. No clarifying questions.
5. **Commit only what is staged.** Run `git commit -m "<message>"`. Never use `git add` and never pass paths to `git commit`.
6. **Report.** State the final message, short hash, and the files committed.

## Rules

- Commit only already-staged files; never stage additional files.
- If nothing is staged, notify the user and create no commit.
- No emoji in commit messages.
- Exclude `*.csv` from all diff inspection.
- Do not ask clarifying questions — decide autonomously and commit immediately.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "There are unstaged changes that belong here, I'll stage them." | Scope is the staged set only. Staging extra files changes the user's intent. |
| "I should ask what type/scope they want." | The diff is sufficient. Decide autonomously and commit. |
| "The branch has no ticket, I'll invent one." | Only use a ticket that literally matches `[A-Z]+-[0-9]+` in the branch name. |
| "A quick emoji makes it friendlier." | Messages stay emoji-free and machine-parseable. |

## Red Flags

- Running `git add` before committing.
- Passing file paths to `git commit`.
- Asking the user to pick a type or scope.
- Committing when `git diff --cached --name-only` is empty.
- Inspecting CSV diffs.

## Verification

- [ ] `git diff --cached --name-only` was non-empty before committing.
- [ ] No `git add` was run; only staged files were committed.
- [ ] Message follows `<type>[(scope)]: [<TICKET> ]<description>` with a valid type.
- [ ] Ticket included only if the branch name matched `[A-Z]+-[0-9]+`.
- [ ] No emoji in the message.
- [ ] Final message, hash, and committed files reported to the user.
