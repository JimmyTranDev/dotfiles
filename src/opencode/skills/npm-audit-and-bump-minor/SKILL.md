---
name: npm-audit-and-bump-minor
description: Audits a Node/npm project for vulnerabilities and bumps every dependency to its latest minor/patch within the same major (never breaking majors), then re-audits and proves the build and tests still pass. Use when the user says "npm audit and bump minor", "update deps to latest minor", "bump npm dependencies", "run npm audit and fix", or wants routine npm dependency-freshness/security maintenance without major upgrades. Standardizes on `npm audit` plus `npx npm-check-updates --target minor`. Do NOT use for intentional major/breaking upgrades, a single CVE that only a major release fixes, or pnpm/yarn projects without adapting the commands.
---

# npm Audit and Bump Minor

## Overview

A repeatable maintenance routine for a Node/npm project: capture a vulnerability baseline with `npm audit`, bump every dependency to its **latest minor/patch within the same major** using `npm-check-updates`, then prove the project still builds and tests pass. Major (breaking) upgrades are deliberately out of scope — they are surfaced for a separate, reviewed upgrade. For deeper security analysis defer to `security-and-hardening`; for wiring this into pipelines defer to `ci-cd-and-automation`.

## When to Use

- The user asks to "npm audit and bump minor", "update deps to latest minor", or "bump npm dependencies".
- Routine dependency-freshness or security-hygiene maintenance on an npm project.

**Do NOT use when:**

- An intentional **major** upgrade is wanted — that is breaking; handle per-package (consider `deprecation-and-migration`).
- A specific CVE is only fixed by a major release — surface it; do not force it here.
- The project uses pnpm or yarn — the audit/update commands differ; adapt or stop.
- There is no `package.json` — this skill is npm-specific.

## The Workflow

1. **Confirm an isolated, clean tree.** Run `git status --porcelain`. If it is dirty, warn the user — dependency changes must land as their own reviewable, revertable change. Don't mix in unrelated edits.
2. **Confirm npm project + install.** Verify `package.json` and `package-lock.json` exist. Run `npm ci` (or `npm install`) so audit and tests run against a real `node_modules`.
3. **Baseline audit.** Run `npm audit`. Record vulnerability counts by severity (use `npm audit --json` if you need exact numbers). This is the before snapshot.
4. **Preview the bumps.** Run `npx npm-check-updates --target minor`. This lists the minor/patch upgrades that will be applied without writing anything. Confirm nothing crosses a major.
5. **Apply the bumps.** Run `npx npm-check-updates --target minor -u`. This rewrites `package.json` to the latest minor/patch ranges. Never use `--target latest`/`--target greatest` and never `npm audit fix --force` — both can introduce breaking majors.
6. **Install & refresh the lockfile.** Run `npm install` so `package-lock.json` matches the new ranges.
7. **Re-audit.** Run `npm audit` again and compare to the baseline. If `npm audit fix` (without `--force`) can clear remaining issues within semver, run it. Anything that still needs a major bump is reported, not forced.
8. **Prove nothing broke.** Run the project's build, test, and lint scripts (e.g. `npm run build`, `npm test`, `npm run lint` — whichever exist in `package.json`). If something fails, hand off to `debugging-and-error-recovery`; consider reverting the specific package that caused it.
9. **Report.** Summarize: vuln counts before → after, the packages bumped (name old → new), build/test result, and any remaining vulnerabilities that require a major upgrade.

## Rules

- **Minor/patch only.** Never let a dependency cross a major version. No `--target latest`, no `npm audit fix --force`.
- Never bump a single package to a new major just to silence an audit finding — surface it instead.
- Always re-run `npm install` after `ncu -u` so the lockfile matches `package.json`.
- Keep the change isolated; do not commit automatically (defer to `commit` / `git-workflow-and-versioning` when the user asks).
- Don't hand-edit version ranges beyond what `npm-check-updates` writes.

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "`npm audit fix --force` clears everything at once." | `--force` installs breaking majors. This skill is minor-only; report majors for a separate upgrade. |
| "The lockfile will sort itself out." | Run `npm install` after `ncu -u` or `package-lock.json` drifts from `package.json` and CI breaks. |
| "Bumps are safe, skip the tests." | Even minor bumps can change behavior. Unverified bumps are not done — run build + tests. |
| "Just take this one package to its new major to fix the CVE." | Majors are breaking and out of scope. Surface it; don't force it in this routine. |
| "The tree was dirty but I'll bump anyway." | Mixing pre-existing edits with dep bumps makes the change unreviewable and hard to revert. |

## Red Flags

- Running `npm audit fix --force` or `ncu --target latest`/`greatest`.
- `package.json` shows a dependency crossing a major (e.g. `3.x` → `4.x`).
- Skipping the re-audit or the build/test run.
- No `npm install` after `ncu -u` (lockfile out of sync).
- Committing the change without being asked.

## Verification

- [ ] Baseline `npm audit` captured before any change.
- [ ] `npx npm-check-updates --target minor -u` was used (no `latest`/`greatest`, no `--force`).
- [ ] No dependency crossed a major version in `package.json`.
- [ ] `npm install` ran; `package-lock.json` updated to match.
- [ ] Re-audit ran and was compared to the baseline.
- [ ] Build, tests, and lint pass (or failures were handed to `debugging-and-error-recovery`).
- [ ] Report includes before/after vuln counts, bumped packages, and any remaining majors.
