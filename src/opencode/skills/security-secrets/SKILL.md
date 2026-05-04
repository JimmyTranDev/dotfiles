---
name: security-secrets
description: "Secret management covering scanning, rotation workflows, vault integration, .env patterns, git-secrets, pre-commit hooks, and CI/CD secrets"
---

## Secret Scanning Tools

| Tool | Scope | Integration |
|------|-------|-------------|
| `gitleaks` | Git history + staged | CLI, CI, pre-commit |
| `trufflehog` | Git history, S3, Slack | CLI, CI |
| `git-secrets` | AWS-focused patterns | Git hooks |
| GitHub Secret Scanning | Push protection | GitHub native |
| `detect-secrets` | Yelp's baseline approach | CLI, pre-commit |

### Gitleaks Quick Start

```bash
gitleaks detect --source . --verbose
gitleaks detect --source . --log-opts="--all"
gitleaks protect --staged
```

### Trufflehog

```bash
trufflehog git file://. --only-verified
trufflehog github --repo=https://github.com/org/repo
```

## .env File Patterns

### File Hierarchy

```
.env                 # shared defaults (committed, no secrets)
.env.local           # local overrides (gitignored)
.env.development     # dev defaults (committed, no secrets)
.env.production      # prod template (committed, no secrets)
.env.*.local         # local env overrides (gitignored)
```

### .gitignore Rules

```
.env.local
.env.*.local
.env.development.local
.env.production.local
```

### Template Pattern

```bash
DATABASE_URL=postgresql://user:password@localhost:5432/mydb
REDIS_URL=redis://localhost:6379
API_KEY=<your-api-key-here>
JWT_SECRET=<generate-with-openssl-rand-base64-32>
```

## Git-Secrets Setup

```bash
brew install git-secrets

git secrets --install
git secrets --register-aws

git secrets --add 'PRIVATE.KEY'
git secrets --add --allowed 'AKIAIOSFODNN7EXAMPLE'

git secrets --scan
git secrets --scan-history
```

### Global Install (all repos)

```bash
git secrets --install ~/.git-templates/git-secrets
git config --global init.templateDir ~/.git-templates/git-secrets
```

## Pre-Commit Hooks

### .pre-commit-config.yaml

```yaml
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.0
    hooks:
      - id: gitleaks

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ["--baseline", ".secrets.baseline"]

  - repo: https://github.com/awslabs/git-secrets
    rev: master
    hooks:
      - id: git-secrets
```

### Setup

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

## Vault Integration

### HashiCorp Vault CLI

```bash
export VAULT_ADDR="https://vault.example.com"
vault login -method=oidc

vault kv get secret/myapp/production
vault kv put secret/myapp/production db_password="newpass123"
vault kv get -field=db_password secret/myapp/production
vault kv metadata get secret/myapp/production
```

### Dynamic Secrets

```bash
vault read database/creds/readonly
```

Returns time-limited credentials that auto-expire.

### Application Integration Pattern

```typescript
import Vault from "node-vault";

const vault = Vault({
  apiVersion: "v1",
  endpoint: process.env.VAULT_ADDR,
  token: process.env.VAULT_TOKEN,
});

const { data } = await vault.read("secret/data/myapp/production");
const dbPassword = data.data.db_password;
```

## Rotation Workflows

### Rotation Checklist

1. Generate new secret
2. Deploy new secret to consumers (dual-read period)
3. Update producers to use new secret
4. Verify all systems healthy
5. Revoke old secret
6. Update documentation/runbook

### Automated Rotation

| Secret Type | Rotation Period | Method |
|-------------|----------------|--------|
| API keys | 90 days | Generate new, deprecate old |
| DB passwords | 30-90 days | Vault dynamic secrets |
| JWT signing keys | 30 days | Key rotation with kid |
| TLS certificates | Before expiry | cert-manager auto-renewal |
| OAuth client secrets | 180 days | Provider rotation API |

### Zero-Downtime DB Password Rotation

```bash
vault write database/rotate-root/mydb
```

Or manual:
1. Create new DB user with same permissions
2. Update app config to new user
3. Deploy and verify
4. Drop old user

## CI/CD Secret Management

### GitHub Actions

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy
        env:
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
        run: ./deploy.sh
```

### GitHub Actions Best Practices

- Use environment-scoped secrets (not repo-level for prod)
- Require approval for production environment
- Never echo secrets: `echo "::add-mask::$SECRET"`
- Use OIDC for cloud provider auth (no long-lived keys)

### OIDC Provider Auth (AWS)

```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::123456789:role/deploy
      aws-region: us-east-1
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Secrets in git history | Rotate immediately, use BFG to clean |
| `.env` committed | Add to `.gitignore`, rotate all values |
| Secrets in logs | Mask in CI, redact in app logging |
| Hardcoded in source | Extract to env vars or vault |
| Shared secrets across envs | Unique per environment |
| No rotation policy | Define and automate rotation |
| Secrets in Docker image | Use build args or runtime mount |
| Secrets in error messages | Sanitize error output |

### Emergency Response: Secret Leaked

1. **Revoke** the secret immediately
2. **Rotate** to a new value
3. **Audit** access logs for unauthorized use
4. **Clean** git history if in repo (BFG Repo-Cleaner)
5. **Document** the incident and update prevention
