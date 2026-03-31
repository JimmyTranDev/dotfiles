---
name: npm-vulnerabilities
description: npm audit workflow covering vulnerability triage, severity classification, resolution strategies, override patterns, and dependency upgrade safety checks
---

## npm audit Commands

| Command | Purpose |
|---------|---------|
| `npm audit` | List all known vulnerabilities |
| `npm audit --json` | Machine-readable output for parsing |
| `npm audit fix` | Auto-install compatible patched versions |
| `npm audit fix --force` | Allow semver-major upgrades (breaking changes) |
| `npm audit signatures` | Verify registry signature integrity |
| `npm audit --omit=dev` | Only audit production dependencies |
| `npm audit --audit-level=critical` | Only report critical severity |

## Severity Levels

| Level | CVSS Score | Action |
|-------|-----------|--------|
| critical | 9.0 - 10.0 | Fix immediately — active exploits likely |
| high | 7.0 - 8.9 | Fix within days — significant risk |
| moderate | 4.0 - 6.9 | Fix within sprint — exploitable under specific conditions |
| low | 0.1 - 3.9 | Fix when convenient — minimal real-world risk |
| info | 0.0 | Informational only — no action needed |

## Resolution Strategies

### 1. Direct Dependency Update

Best case — the vulnerable package is a direct dependency:

```bash
npm install package-name@latest
```

Verify the update:
```bash
npm ls package-name
npm audit
```

### 2. Transitive Dependency Override

When the vulnerability is in a nested dependency and the direct parent hasn't released a fix:

```json
{
  "overrides": {
    "vulnerable-package": ">=fixed-version"
  }
}
```

Scoped overrides for specific dependency trees:

```json
{
  "overrides": {
    "parent-package": {
      "vulnerable-package": ">=fixed-version"
    }
  }
}
```

After adding overrides:
```bash
rm -rf node_modules package-lock.json
npm install
npm audit
```

### 3. npm audit fix

Auto-resolve with semver-compatible updates:

```bash
npm audit fix
```

For stubborn vulnerabilities requiring major version bumps:

```bash
npm audit fix --force
```

### 4. Package Replacement

When a package is abandoned or permanently vulnerable:

| Abandoned Package | Replacement |
|-------------------|-------------|
| `request` | `undici`, `got`, `ky` |
| `node-uuid` | `uuid` |
| `querystring` | `URLSearchParams` (built-in) |
| `mkdirp` (old) | `fs.mkdirSync(path, { recursive: true })` |
| `rimraf` (old) | `fs.rmSync(path, { recursive: true })` |

## Parsing npm audit JSON

Key fields in `npm audit --json` output:

| Field Path | Description |
|------------|-------------|
| `vulnerabilities.<name>.severity` | Severity level |
| `vulnerabilities.<name>.via` | Advisory details or dependency chain |
| `vulnerabilities.<name>.fixAvailable` | Whether a fix exists |
| `vulnerabilities.<name>.range` | Affected version range |
| `vulnerabilities.<name>.isDirect` | Whether it's a direct dependency |
| `metadata.vulnerabilities` | Count by severity |

## Triage Decision Tree

```
Is the vulnerability in a production dependency?
├── Yes → Is a patched version available?
│   ├── Yes → Is it a direct dependency?
│   │   ├── Yes → npm install package@fixed-version
│   │   └── No → Add override, then npm install
│   └── No → Is there an alternative package?
│       ├── Yes → Replace the dependency
│       └── No → Document risk, monitor for fix
└── No (devDependency only) → Is it exploitable in dev context?
    ├── Yes (e.g., dev server RCE) → Fix using same strategies above
    └── No → Lower priority, fix when convenient
```

## Override Patterns

### Pin Transitive Dependency

```json
{
  "overrides": {
    "semver": "^7.5.4"
  }
}
```

### Override Only Within Specific Parent

```json
{
  "overrides": {
    "@angular/cli": {
      "tar": "^6.2.1"
    }
  }
}
```

### Use Version From Direct Dependency

```json
{
  "overrides": {
    "glob": "$glob"
  }
}
```

The `$` prefix references the version of `glob` listed in your own `dependencies` or `devDependencies`.

## Post-Fix Verification

After applying any fix:

1. `npm audit` — confirm vulnerability count decreased
2. `npm ls <package>` — verify correct version resolved
3. `npm test` — confirm no regressions
4. `npm run build` — confirm build still works
5. Check changelog of upgraded packages for breaking changes

## Common Gotchas

| Issue | Fix |
|-------|-----|
| `npm audit fix` does nothing | Vulnerability is in transitive dep — use overrides |
| Override not taking effect | Delete `node_modules` and `package-lock.json`, reinstall |
| `--force` breaks things | Review breaking changes in changelogs before force-updating |
| Same vuln reappears after fix | Multiple dependency paths — check `npm ls <package>` for all instances |
| Audit reports vuln in dev dep | Use `--omit=dev` to check prod-only, deprioritize dev-only vulns |
| `ERESOLVE` conflict with override | Ensure override version satisfies peer dependency requirements |
| lockfile out of sync | Run `npm install --package-lock-only` to regenerate without modifying `node_modules` |

## Supply Chain Attack Prevention

Delay installation of newly published dependency versions to allow time for the community to detect malicious packages before they reach your project.

### pnpm: minimumReleaseAge

In `pnpm-workspace.yaml`, set `minimumReleaseAge` (in minutes) to block packages published less than N days ago. 7 days = 10080 minutes:

```yaml
packages:
  - '.'

minimumReleaseAge: 10080
minimumReleaseAgeExclude:
  - '@your-org/*'
trustPolicy: no-downgrade
```

| Setting | Purpose |
|---------|---------|
| `minimumReleaseAge` | Minutes a package version must exist on the registry before pnpm will install it |
| `minimumReleaseAgeExclude` | Packages exempt from the age gate (e.g., internal scoped packages) |
| `trustPolicy: no-downgrade` | Fail if a package's trust level has decreased compared to previous releases |

### Dependabot: cooldown

In `.github/dependabot.yml`, add `cooldown.default-days` to delay Dependabot version update PRs until a new version has been published for N days:

```yaml
version: 2
updates:
  - package-ecosystem: 'npm'
    directory: '/'
    schedule:
      interval: 'daily'
    cooldown:
      default-days: 7
    groups:
      production-dependencies:
        dependency-type: "production"
      development-dependencies:
        dependency-type: "development"
```

| Setting | Purpose |
|---------|---------|
| `cooldown.default-days` | Days to wait after a new version is published before Dependabot creates a PR |
| `groups` | Group dependency updates by type to reduce PR noise |

### Why 7 Days?

Most malicious npm packages are detected and removed within 24-72 hours. A 7-day cooldown provides a safety margin that catches the vast majority of supply chain attacks while keeping dependencies reasonably current.

### Verification Checklist

When auditing a project's supply chain defenses:

1. Check for `minimumReleaseAge` in `pnpm-workspace.yaml` (pnpm projects)
2. Check for `cooldown` in `.github/dependabot.yml` (GitHub-hosted projects)
3. Verify `trustPolicy: no-downgrade` is set (pnpm projects)
4. Verify `npm audit signatures` passes (registry signature integrity)
5. Ensure internal/scoped packages are excluded from age gates to avoid blocking your own releases

## pnpm Equivalents

| npm | pnpm |
|-----|------|
| `npm audit` | `pnpm audit` |
| `npm audit fix` | `pnpm audit --fix` |
| `npm audit --json` | `pnpm audit --json` |
| `overrides` in package.json | `pnpm.overrides` in package.json |
| `npm ls <package>` | `pnpm ls <package>` |
