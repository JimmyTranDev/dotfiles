---
name: audit
description: Scan npm dependencies for security vulnerabilities and supply chain defenses
---

Audit npm dependencies for known vulnerabilities, check supply chain defenses, and report findings. This command is read-only — it does not modify files, create branches, or open PRs. Use `/pr-audit` to apply fixes.

Usage: /audit [scope]

$ARGUMENTS

Load the **npm-vulnerabilities** skill.

1. Pull latest changes:
   - Run `git pull` to ensure the working tree is up to date with the remote before auditing

2. Check supply chain defenses (using the **Supply Chain Attack Prevention** section of the **npm-vulnerabilities** skill):
   - Detect package manager: check for `pnpm-lock.yaml` (pnpm) or `package-lock.json` (npm)
   - For pnpm projects: check `pnpm-workspace.yaml` for `minimumReleaseAge` (should be >= 10080) and `trustPolicy: no-downgrade`
   - For GitHub-hosted projects: check `.github/dependabot.yml` for `cooldown.default-days` (should be >= 7)
   - Run `npm audit signatures` to verify registry signature integrity
   - Report any missing supply chain defenses

3. Determine the scope:
   - If the user specifies a severity filter (e.g., "critical only"), apply `--audit-level` accordingly
   - If the user specifies `--omit=dev`, audit production dependencies only
   - If no scope is given, run a full audit of all dependencies

4. Run the audit:
   - Execute `npm audit --json` (or `pnpm audit --json`) to get machine-readable vulnerability data
   - Parse the output to extract vulnerability count, severity breakdown, affected packages, and fix availability
   - If no vulnerabilities are found, report clean status and stop

5. Triage using the **npm-vulnerabilities** skill decision tree:
   - Classify each vulnerability by severity (critical, high, moderate, low)
   - Determine if each is a direct or transitive dependency
   - Check if a fix is available (`fixAvailable` field)
   - Separate production vulnerabilities from dev-only vulnerabilities

6. Present findings to the user:
   - Supply chain defense status (what is configured, what is missing)
   - Summary table: count by severity, direct vs transitive, fix available vs no fix
   - For each critical/high vulnerability: package name, advisory URL, affected version range, and recommended action
   - For moderate/low: grouped summary with package names and fix availability
   - Suggest running `/pr-audit` to apply fixes in a worktree and create a draft PR

Important:
- This command is read-only — do not modify any files, create branches, or open PRs
- Use the appropriate package manager commands based on the detected lockfile
