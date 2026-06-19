---
name: tool-github-actions
description: GitHub Actions workflow patterns covering job structure, caching, matrix builds, reusable workflows, secrets, artifact handling, and common failure debugging
---

## Workflow File Structure

| File | Purpose |
|------|---------|
| `.github/workflows/*.yml` | Workflow definitions (triggered by events) |
| `.github/actions/*/action.yml` | Composite actions (reusable steps) |

## Common Triggers

```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
  workflow_dispatch:
    inputs:
      environment:
        type: choice
        options: [staging, production]
```

## Job Structure

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 15
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version-file: '.nvmrc'
          cache: 'npm'
      - run: npm ci
      - run: npm run build
```

## Caching Patterns

| Cache target | Key strategy |
|-------------|--------------|
| npm/pnpm/yarn | `${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}` |
| Gradle | `${{ runner.os }}-gradle-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}` |
| Maven | `${{ runner.os }}-maven-${{ hashFiles('**/pom.xml') }}` |
| Docker layers | `type=gha` with `docker/build-push-action` |

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.npm
    key: ${{ runner.os }}-node-${{ hashFiles('**/package-lock.json') }}
    restore-keys: |
      ${{ runner.os }}-node-
```

## Matrix Builds

```yaml
strategy:
  fail-fast: false
  matrix:
    node-version: [18, 20, 22]
    os: [ubuntu-latest, macos-latest]
    exclude:
      - os: macos-latest
        node-version: 18
```

## Reusable Workflows

```yaml
# .github/workflows/reusable-deploy.yml
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy-key:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - run: echo "Deploying to ${{ inputs.environment }}"
```

Caller:
```yaml
jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
    secrets:
      deploy-key: ${{ secrets.DEPLOY_KEY }}
```

## Artifacts

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: build-output
    path: dist/
    retention-days: 5

- uses: actions/download-artifact@v4
  with:
    name: build-output
    path: dist/
```

## Secrets and Environment Variables

| Scope | Access |
|-------|--------|
| Repository secrets | `${{ secrets.NAME }}` |
| Environment secrets | Require `environment:` in job |
| Variables | `${{ vars.NAME }}` |
| GITHUB_TOKEN | Auto-provided, scoped to repo |

## Conditional Execution

```yaml
- run: npm run deploy
  if: github.ref == 'refs/heads/main' && github.event_name == 'push'

- run: npm run e2e
  if: contains(github.event.pull_request.labels.*.name, 'e2e')
```

## Common Failure Patterns

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| `ENOSPC` | Disk full from caches/artifacts | Add cleanup step or reduce cache |
| `Error: Process completed with exit code 137` | OOM killed | Use larger runner or reduce parallelism |
| `Error: Resource not accessible by integration` | GITHUB_TOKEN scope | Add `permissions:` block |
| Timeout on npm install | Registry issue or large deps | Add `--prefer-offline`, use cache |
| `Permission denied` on script | Not executable | Add `chmod +x` step or `run: bash script.sh` |
| Flaky test failures | Race conditions or network | Add retries with `nick-fields/retry@v3` |

## Permissions

```yaml
permissions:
  contents: read
  pull-requests: write
  issues: write
  packages: read
```

## Debugging

```yaml
- run: npm test
  env:
    ACTIONS_STEP_DEBUG: true

- uses: actions/upload-artifact@v4
  if: failure()
  with:
    name: debug-logs
    path: |
      **/test-results/
      **/playwright-report/
```

## gh CLI in Workflows

```yaml
- run: gh pr comment ${{ github.event.pull_request.number }} --body "Build passed ✅"
  env:
    GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## What This Skill Does NOT Cover

- Self-hosted runner setup and maintenance — infrastructure-specific
- GitHub Apps and OAuth flows — see **security** skill for auth patterns
- Docker image building best practices — out of scope
