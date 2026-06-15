---
description: Audit npm/pnpm dependencies for vulnerabilities and apply safe fixes
argument-hint: "[directory]"
---

Usage: /npm-audit-fix [directory]

Audit the project's JavaScript dependencies for known vulnerabilities and apply safe, semver-compatible fixes. Surface any breaking or forced upgrades for confirmation before applying them.

$ARGUMENTS

## Skills

Load the **security-npm-vulnerabilities** skill at the start — it defines severity levels, the triage decision tree, override patterns, and pnpm/workspace equivalents. Use it to classify and resolve every finding.

## Workflow

1. **Detect the project and package manager**:
   - Run `detect-stack.sh` to confirm a JavaScript/TypeScript project and identify the package manager (npm vs pnpm) and whether it is a monorepo workspace
   - If no `package.json` is found, notify the user and stop
   - If the project is not a JS project (no `package.json`), notify the user and stop

2. **Audit the dependencies**:
   - Run `check-deps.sh` to gather the outdated + audit report, and `security-scan.sh` for combined secret + dependency audit (run both in parallel)
   - Do NOT reimplement audit logic — consume the JSON output from these scripts
   - Parse the vulnerability counts by severity (critical, high, moderate, low)

3. **Classify findings** (per the **security-npm-vulnerabilities** skill):
   - Group vulnerabilities by severity and whether they are direct or transitive
   - Apply the triage decision tree to decide the resolution strategy for each (direct update, override, replacement, or `audit fix`)

4. **Apply safe fixes**:
   - Run `npm audit fix` (or `pnpm audit --fix` for pnpm projects) to apply semver-compatible patches only
   - Do NOT run `--force` automatically

5. **Surface breaking/forced fixes for confirmation**:
   - For any vulnerability that only resolves via a semver-major upgrade (`npm audit fix --force`) or a transitive override, list each one with its package, severity, current/target version, and the breaking-change risk
   - Use the question tool to ask the user whether to apply the forced/breaking fixes. Only apply the ones the user approves.

6. **Verify**:
   - Re-run the audit (`check-deps.sh`) to confirm the vulnerability count decreased
   - Run `run-tests.sh` and `build-check.sh` (in parallel) to confirm no regressions if the project has them
   - If a forced upgrade broke tests or the build, report which fix caused it

7. **Report**: Summarize the before/after vulnerability counts by severity, which fixes were applied automatically, which forced fixes were applied with confirmation, and any vulnerabilities left unresolved with the reason.

## Constraints

- Reuse the **security-npm-vulnerabilities** skill and the `check-deps.sh` / `security-scan.sh` scripts — never reimplement audit logic inline
- Never apply `--force` or breaking upgrades without explicit user confirmation
- For monorepo workspaces, use the workspace-aware commands and root-level overrides described in the skill
