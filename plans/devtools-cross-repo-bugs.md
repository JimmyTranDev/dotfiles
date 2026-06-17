---
todoist:
  - https://app.todoist.com/app/task/check-why-backup-restore-always-lead-to-empty-courses-and-cant-acquire-any-new-courses-6grvG5mJghcC69Wm
  - https://app.todoist.com/app/task/the-progress-is-incrementing-slighly-wrong-so-that-the-numerator-is-higher-than-the-denominator-in-studyscreen-6gvCqRWRghMf9H6m
---

# Devtools: Cross-Repo Bug Investigations (External Apps)

> **NOTE:** Both tasks here are bugs in applications that live **outside the dotfiles repo**. They cannot be implemented in dotfiles. This spec captures the symptom, likely cause hypotheses, and the investigation plan so the fix can be executed quickly in the correct repo. Earlier clarification flagged these as cross-repo; they are included only because the scope decision was "everything still p1".

## TL;DR
- Two bug investigations in external apps: (1) backup restore always yields empty courses and blocks acquiring new courses; (2) study-screen progress shows numerator > denominator.
- Neither touches dotfiles — implementation belongs in the respective app repos (to be identified).
- Most critical: the backup-restore bug is data-integrity/blocking (users can't get courses); the progress bug is a display/logic error.
- Estimated effort: unknown until the repos are located; investigation-first.
- **Blocked**: need the repo + tech stack for each app before real tasks can be written.

## Overview
Two correctness bugs reported against external applications. This spec documents reproduction context and hypotheses to accelerate the fix once work moves into the owning repositories.

## Architecture
- Unknown — the owning repos are not part of dotfiles. Likely a learning/study app (courses, study screen, backup/restore). Tech stack TBD (candidates given other skills present: Expo/React Native + a local DB like SQLite/Drizzle, or a Spring backend).

## Data flow (hypothesized)
- **Backup/restore**: export courses → serialize → store backup → on restore, deserialize → write to DB. Empty-courses-after-restore suggests the restore writes an empty/!mismatched dataset or clears courses before a failing import, and "can't acquire new courses" suggests the acquire path reads stale/empty state or a broken foreign key/migration.
- **Progress**: a counter increments a numerator independent of (or faster than) the denominator, or the denominator is computed on a filtered set while the numerator counts the unfiltered set → numerator > denominator.

## Tasks
| # | File | Change | Complexity | Deps | Parallel? |
|---|------|--------|------------|------|-----------|
| 1 | (external repo) | #3: locate the backup/restore code; reproduce empty-courses-after-restore; confirm whether restore clears courses before a failing import and why "acquire new courses" then fails | Large | repo id | N/A |
| 2 | (external repo) | #3 fix: make restore atomic (don't clear until import validated) and fix the acquire path | Medium | 1 | N/A |
| 3 | (external repo) | #23: locate study-screen progress calc; reproduce numerator > denominator; identify the off-by-one / mismatched-set source | Medium | repo id | N/A |
| 4 | (external repo) | #23 fix: clamp/recompute so numerator ≤ denominator and counts come from the same set | Small | 3 | N/A |

## API contracts
- N/A until the owning repos and their data models are known.

## State changes
- Likely DB writes in the external app (courses table, progress counters) — defined in the owning repo.

## Edge cases
- **Restore**: empty backup file, partially-corrupt backup, restore interrupted mid-write, schema/version mismatch between backup and current app.
- **Progress**: completing an item twice, items removed after progress recorded, denominator of zero, concurrent updates double-incrementing the numerator.

## Testing approach
- **#3**: unit test restore with a known non-empty backup → courses present; test restore-then-acquire flow; test restore atomicity on a forced import failure.
- **#23**: unit test progress with edge counts (0/0, all complete, item removed mid-session) asserting numerator ≤ denominator.

## Open questions
### Scope
- **Which repos own these apps?** Required before any implementation. (Recommend: identify the study app repo and confirm whether it has a backend or is local-only.) — **Blocking, Decision pending.**
### Architecture
- **#3** — is restore transactional today? Does it clear-then-import or import-then-swap? (Determines whether the fix is ordering or validation.)
- **#23** — is the denominator the total course items or a filtered subset (e.g. due items)? (Determines whether numerator and denominator must be recomputed from the same query.)
### Risks
- Data-integrity bug (#3) may have already corrupted user backups — consider a migration/repair path, not just a forward fix.
