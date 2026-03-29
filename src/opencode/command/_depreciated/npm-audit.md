---
name: npm-audit
description: Scan npm dependencies for vulnerabilities and apply fixes with verification
---

Audit npm dependencies for known vulnerabilities, triage by severity, and apply fixes.

Usage: /npm-audit [scope]

$ARGUMENTS

1. Determine the scope:
   - If the user specifies a severity filter (e.g., "critical only"), apply `--audit-level` accordingly
   - If the user specifies `--omit=dev`, audit production dependencies only
   - If no scope is given, run a full audit of all dependencies

2. Run the audit:
   - Execute `npm audit --json` to get machine-readable vulnerability data
   - Parse the output to extract vulnerability count, severity breakdown, affected packages, and fix availability
   - If no vulnerabilities are found, notify the user and stop

3. Load the **npm-vulnerabilities** skill, then triage using its decision tree:
   - Classify each vulnerability by severity (critical, high, moderate, low)
   - Determine if each is a direct or transitive dependency
   - Check if a fix is available (`fixAvailable` field)
   - Separate production vulnerabilities from dev-only vulnerabilities

4. Present findings to the user:
   - Summary table: count by severity, direct vs transitive, fix available vs no fix
   - For each critical/high vulnerability: package name, advisory URL, affected version range, and recommended action
   - Ask the user to confirm before applying fixes

5. Apply fixes incrementally, starting with the safest:
   - **Phase 1**: Run `npm audit fix` for semver-compatible auto-fixes
   - **Phase 2**: For remaining transitive vulnerabilities, add `overrides` to `package.json`
   - **Phase 3**: For direct dependencies with major version bumps available, present breaking changes and ask user before upgrading
   - Skip `npm audit fix --force` unless the user explicitly requests it

6. After each phase, verify:
   - Run `npm audit` to confirm vulnerability count decreased
   - Run `npm test` and `npm run build` (if available) to catch regressions
   - If a fix introduces test failures, revert the change and report the conflict to the user

7. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to:
   - **reviewer**: Verify that `package.json` and `package-lock.json` changes are correct and overrides are properly scoped
   - **tester**: Run the full test suite to confirm no regressions from dependency updates

8. After all fixes are applied:
   - Run a final `npm audit` to confirm remaining vulnerability count
   - Summarize what was fixed: packages upgraded, overrides added, packages replaced
   - List any unresolved vulnerabilities with explanation of why they can't be auto-fixed and recommended manual actions
