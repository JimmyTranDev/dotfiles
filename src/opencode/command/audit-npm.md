---
description: Audit an npm project and bump every dependency to its latest minor/patch (no majors), then re-audit and prove the build and tests still pass
---

Load the `npm-audit-and-bump-minor` skill with the skill tool and follow its
workflow exactly to audit and refresh the npm project's dependencies.

`$ARGUMENTS` is an optional path to the npm project to work in; if empty, use the
current directory. Confirm a `package.json` exists there before starting.

Specifically:

1. Confirm a clean, isolated tree (`git status --porcelain`); warn if dirty.
2. Capture a baseline `npm audit` (vuln counts by severity) before any change.
3. Preview bumps with `npx npm-check-updates --target minor`, then apply with
   `-u`. Never use `--target latest`/`greatest` and never `npm audit fix --force`
   — no dependency may cross a major version.
4. Run `npm install` so `package-lock.json` matches, then re-audit and compare to
   the baseline.
5. Prove nothing broke — run the project's build, test, and lint scripts
   (whichever exist). On failure, load `debugging-and-error-recovery`.
6. Do **not** commit unless I ask.
7. Report: before → after vuln counts, the packages bumped (name old → new),
   the build/test/lint result, and any remaining issues that need a major upgrade.
