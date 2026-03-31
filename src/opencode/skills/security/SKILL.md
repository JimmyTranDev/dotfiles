---
name: security
description: Security vulnerability categories, severity classification, attack vectors, and remediation patterns for code auditing
---

Scan code for exploitable vulnerabilities. Classify severity, explain attack vectors, provide exact fixes.

## Vulnerability Categories

### Injection

| Type | Signal | Fix |
|------|--------|-----|
| SQL injection | String concatenation in queries | Parameterized queries / prepared statements |
| XSS (reflected) | User input rendered in HTML without escaping | Context-aware output encoding |
| XSS (stored) | Database content rendered without sanitization | Sanitize on output, CSP headers |
| Command injection | User input in `exec`, `spawn`, `system` calls | Allowlist commands, avoid shell interpolation |
| Path traversal | User input in file paths (`../`) | Resolve and validate against base directory |
| Template injection | User input in template strings | Sandbox templates, avoid user-controlled templates |
| Header injection | User input in HTTP headers | Strip newlines, validate header values |
| LDAP injection | User input in LDAP queries | Escape special characters, parameterize |

### Authentication and Authorization

| Type | Signal | Fix |
|------|--------|-----|
| Missing auth check | Endpoint without middleware/guard | Add authentication middleware |
| Broken access control | No ownership verification on resources | Verify resource ownership before access |
| Privilege escalation | Role check bypassable or missing | Server-side role validation on every request |
| Insecure password storage | Plain text or weak hashing (MD5, SHA1) | bcrypt/scrypt/argon2 with salt |
| Session fixation | Session ID not rotated after login | Regenerate session on authentication |
| JWT issues | No expiry, weak secret, algorithm confusion | Short expiry, strong secret, explicit algorithm |
| Missing CSRF protection | State-changing endpoints without CSRF tokens | CSRF tokens on all mutating requests |

### Secrets and Credentials

| Type | Signal | Fix |
|------|--------|-----|
| Hardcoded secrets | API keys, passwords, tokens in source | Environment variables or secret manager |
| Secrets in logs | Logging request bodies, tokens, passwords | Redact sensitive fields before logging |
| Secrets in error messages | Stack traces or config exposed to users | Generic error messages in production |
| `.env` committed | `.env` in git history | Add to `.gitignore`, rotate all exposed secrets |
| Secrets in URLs | Tokens in query parameters | Use headers (Authorization, cookies) |

### Data Exposure

| Type | Signal | Fix |
|------|--------|-----|
| Verbose errors | Stack traces, SQL errors sent to client | Generic error responses, log details server-side |
| Sensitive data in logs | PII, credentials, tokens logged | Structured logging with field redaction |
| Missing response filtering | Full database objects returned to client | DTO/projection layer, return only needed fields |
| Insecure data transmission | HTTP instead of HTTPS | Enforce HTTPS, HSTS headers |
| Excessive CORS | `Access-Control-Allow-Origin: *` | Restrict to known origins |

### Input Validation

| Type | Signal | Fix |
|------|--------|-----|
| Missing validation | User input used directly without checks | Validate type, format, length, range |
| Incomplete validation | Client-side only validation | Server-side validation for all inputs |
| ReDoS | Complex regex on user input | Limit input length, use safe regex patterns |
| Mass assignment | Spreading request body into model | Explicit allowlist of assignable fields |
| Type coercion | Truthy/falsy checks on security-critical values | Strict equality, explicit type checks |
| File upload | No type/size validation on uploads | Validate MIME type, extension, size limits |

### Insecure Dependencies

| Type | Signal | Fix |
|------|--------|-----|
| Known vulnerabilities | `npm audit` / `cargo audit` findings | Update to patched version |
| Unmaintained packages | No updates in 2+ years, open CVEs | Replace with maintained alternative |
| Typosquatting | Package name similar to popular package | Verify package publisher and download counts |
| Excessive permissions | Package requesting unnecessary system access | Review package scope, consider alternatives |

## Severity Classification

| Severity | Criteria | Examples |
|----------|----------|----------|
| Critical | Remote code execution, auth bypass, data breach | SQL injection, command injection, broken auth |
| High | Significant data exposure, privilege escalation | XSS, IDOR, missing access control |
| Medium | Limited data exposure, requires specific conditions | CSRF, open redirect, information disclosure |
| Low | Minor information leak, defense-in-depth gaps | Missing security headers, verbose errors |

## Attack Vector Analysis

For each vulnerability, document:

1. **Entry point** — where attacker-controlled input enters the system
2. **Data flow** — how the input travels through the code
3. **Exploitation** — what an attacker can achieve
4. **Impact** — data loss, unauthorized access, service disruption
5. **Proof of concept** — minimal example demonstrating the issue

## Remediation Priority

```
Is it exploitable remotely without authentication?
├─ Yes → CRITICAL — fix immediately
└─ No  → Does exploitation expose sensitive data?
         ├─ Yes → HIGH — fix within current sprint
         └─ No  → Does it require specific conditions?
                  ├─ Yes → MEDIUM — schedule fix
                  └─ No  → LOW — fix when touching the code
```

## Secure Coding Patterns

### Input Boundary Validation

```typescript
const parseUserId = (input: unknown): string => {
  if (typeof input !== 'string') throw new ValidationError('Invalid user ID')
  if (!/^[a-zA-Z0-9-]{1,36}$/.test(input)) throw new ValidationError('Invalid user ID format')
  return input
}
```

### Safe Database Queries

```typescript
const getUser = (id: string) =>
  db.query('SELECT id, name, email FROM users WHERE id = $1', [id])
```

### Safe File Path Handling

```typescript
const resolveUploadPath = (filename: string): string => {
  const sanitized = path.basename(filename)
  const resolved = path.resolve(UPLOAD_DIR, sanitized)
  if (!resolved.startsWith(UPLOAD_DIR)) throw new Error('Path traversal detected')
  return resolved
}
```

### Safe Error Responses

```typescript
const handleError = (error: unknown, res: Response) => {
  logger.error('Request failed', { error })
  res.status(500).json({ message: 'Internal server error' })
}
```

## What This Skill Does NOT Cover

- Dependency vulnerability triage and npm audit workflows — see `npm-vulnerabilities` skill
- Supply chain attack prevention (lockfile integrity, release age) — see `npm-vulnerabilities` skill
- Infrastructure security (firewall rules, TLS config, container hardening)
- Penetration testing methodology
