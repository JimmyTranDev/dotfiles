---
description: Implement a feature or Jira ticket end-to-end inside a dedicated wcreated git worktree — spec, plan, build, verify, review — then open a pull request (draft by default); pass a `yolo` keyword to run autonomously with no gates
---

Implement **$ARGUMENTS** inside a dedicated `wcreated` git worktree and finish by
opening a **pull request**. This is `/implement-worktree` plus PR publication.

## Modifiers, worktree, and core flow

Parse `$ARGUMENTS` and run **everything `/implement-worktree` does** — the same
`yolo` and Jira modifiers, Phase 0 worktree setup (plus Jira intake when a key
was passed), and the identical Phases 1–5 core flow (spec → plan → build →
verify → review) inside the worktree — up to but **not** including its Phase 6.

## Phase 6 — Pull request

Once the change is built, verified, and reviewed:

1. **Commit everything.** Load the `commit` skill and commit all work with
   conventional messages (include the Jira key when present). The tree must be
   clean — `git status` shows nothing to commit — before continuing.
2. **Push the branch:** `git push -u origin <branch>`.
3. **Publish a PR.**
   - **Gated (default)** — use the `question` tool with exactly these two
     options:
     - **Draft PR (Recommended)** — open a draft so CI runs and you can do a
       final pass in the PR UI before pinging reviewers; mark ready in one click
       later.
       `gh pr create --draft --base <base> --title "<title>" --body "<body>"`
     - **Open PR (ready for review)** — the work is already verified and
       reviewed, so request review immediately.
       `gh pr create --base <base> --title "<title>" --body "<body>"`
   - **`yolo`** — skip the question and open a **draft** PR automatically. A
     ready-for-review PR pings reviewers — an external side effect — so never do
     that without asking.
4. **Create the PR** for the chosen option. Set:
   - `--base` to the worktree's base branch (the `develop`/`main`/`master` it
     was cut from); head is the current branch.
   - **Title** from the spec objective (or `<KEY> <summary>` for a Jira ticket).
   - **Body** summarizing what changed and how it was verified
     (tests/build/lint), plus the Jira link
     `https://storebrand.atlassian.net/browse/<KEY>` when a ticket exists.

   Report the PR URL.

If a Jira key was passed, run **`/implement`'s Phase 6 — report back to Jira**,
including the **PR link** in the comment and proposing the `"In Review"`
transition.

## Done

Report: the worktree path + branch + base branch, the spec summary, any
clarifications/confirms and how they were resolved, the task list with each
task's status, the verify results (tests / build / lint / coverage), the review
findings and how they were resolved, anything noted-but-not-touched, the PR
decision (draft / ready) with its URL, and — for a Jira ticket — the comment
posted and the ticket's resulting status.
