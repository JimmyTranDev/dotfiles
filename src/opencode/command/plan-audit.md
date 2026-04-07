---
name: plan-audit
description: Analyze dependency versions and audit vulnerabilities without making changes, report what pr-audit would do
---

Usage: /plan-audit [--base=<branch>] [--major]

Analyze the project's dependency versions and security audit status without making any changes. Report which packages have available minor updates, which have major updates, current vulnerabilities, supply chain defense status, and what `/pr-audit` would do if run.

$ARGUMENTS

Load the **npm-vulnerabilities** and **git-workflows** skills in parallel.

1. Determine scope from `$ARGUMENTS`:
   - If `$ARGUMENTS` contains `--base=<branch>`, use it as the base branch
   - Otherwise use the priority order from the **git-workflows** skill (`develop` > `main` > `master`)
   - If `$ARGUMENTS` contains `--major`, include major version bumps in the report

2. Detect package manager:
   - Check for `pnpm-lock.yaml` (pnpm) or `package-lock.json` (npm)
   - If neither exists, notify the user and stop

3. Check supply chain defenses (using the **Supply Chain Attack Prevention** section of the **npm-vulnerabilities** skill):
   - For pnpm projects: check `pnpm-workspace.yaml` for `minimumReleaseAge` (should be >= 10080) and `trustPolicy: no-downgrade`
   - For GitHub-hosted projects: check `.github/dependabot.yml` for `cooldown.default-days` (should be >= 7)
   - Run `npm audit signatures` to verify registry signature integrity
   - Report each defense as present or missing

4. Discover available version updates (do NOT apply any changes):
   - For pnpm projects: run `pnpm outdated --format json` to list all packages with available updates
   - For npm projects: run `npx npm-check-updates --target minor` (dry run, no `-u`) to list available minor bumps, and `npx npm-check-updates` to list all available bumps including major
   - Categorize each available update as patch, minor, or major
   - Flag any packages that would be blocked by `minimumReleaseAge` or `trustPolicy`

5. Run dependency audit (do NOT apply fixes):
   - For pnpm projects: run `pnpm audit --json`
   - For npm projects: run `npm audit --json`
   - Categorize vulnerabilities by severity (critical, high, moderate, low)
   - For each vulnerability, note the affected package, severity, advisory URL, and whether it's a direct or transitive dependency

6. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - **Supply chain defenses**: table showing each defense and its status (present/missing/misconfigured)
   - **Available minor updates**: grouped by dependency type (`dependencies`, `devDependencies`, `peerDependencies`) with a markdown table showing package, current version, and available version
   - **Available major updates**: separate table (only if `--major` is passed or there are fewer than 10)
   - **Blocked updates**: packages blocked by `minimumReleaseAge` or `trustPolicy` with reason
   - **Audit vulnerabilities**: grouped by severity with package name, advisory, and whether a fix is available
   - **Summary stats**: total outdated packages (patch/minor/major), total vulnerabilities by severity, supply chain score

7. Recommend next steps:
   - If there are actionable updates or vulnerabilities, suggest running `/pr-audit` to apply them
   - If supply chain defenses are missing, suggest running `/implement` to add them
   - If there are major-only updates with no minor path, flag them for manual review
   - Estimate the impact of running `/pr-audit` (how many packages would be bumped, how many vulnerabilities would be resolved)

8. Output findings directly in chat as the final response. If the user specifies an output destination (file path, format, etc.), write there instead.
   - When writing to a file, append a new section with a timestamp header (create the file if it doesn't exist)
   - Include all sections from step 6 and recommendations from step 7
