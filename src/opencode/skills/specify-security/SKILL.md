---
name: specify-security
description: Specify skill for security analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`security-`

## Skills to Load

- **security**: Security vulnerability categories, severity classification, attack vectors, remediation
- **code-follower**: Match existing codebase conventions
- **code-conventions**: Coding conventions
- **security-npm-vulnerabilities**: npm audit workflow (optional, if Node.js project)

## Agents to Launch

- **auditor**: Deep scan for exploitable vulnerabilities with specific attack vectors
- **reviewer**: Analyze code patterns for correctness issues that overlap with security (race conditions, error handling, input validation)

## Analysis Categories

- **Injection**: SQL injection, NoSQL injection, command injection, LDAP injection, XPath injection, template injection — string concatenation in queries, unsanitized user input to shell commands, eval/Function constructors, dynamic template rendering
- **Cross-site scripting (XSS)**: Reflected, stored, and DOM-based XSS — `dangerouslySetInnerHTML`, `innerHTML`, `document.write`, unsanitized URL parameters, missing output encoding
- **Authentication**: Weak password policies, missing rate limiting on login, insecure token storage, missing token expiration, hardcoded credentials, timing attacks, missing MFA enforcement
- **Authorization**: Missing access control checks on API routes, IDOR, privilege escalation paths, missing role validation, client-side-only authorization, GraphQL queries exposing unauthorized data
- **Data exposure**: Sensitive data in logs, verbose error messages in production, over-fetched API responses, secrets in client-side bundles, PII in URLs
- **CSRF and request forgery**: Missing CSRF tokens, SameSite cookie misconfiguration, missing Origin/Referer validation, CORS misconfiguration
- **Insecure cryptography**: Weak hashing (MD5, SHA1 for passwords), missing salt, hardcoded encryption keys, Math.random for security, deprecated TLS
- **SSRF**: User-controlled URLs passed to server-side fetch without validation, missing allowlist for outbound requests
- **File handling**: Unrestricted file uploads, path traversal, serving user-uploaded files without content-type validation
- **Session management**: Insecure session configuration, missing HttpOnly/Secure flags, session fixation, missing invalidation on logout
- **API security**: Missing input validation, missing rate limiting, mass assignment, missing pagination limits, GraphQL depth/complexity limits
- **Unsafe patterns**: `eval`, `new Function`, `setTimeout/setInterval` with strings, prototype pollution, ReDoS, uncontrolled resource consumption

### Documentation per Finding

- What's wrong and which category it falls under
- How it's exploitable with a concrete attack scenario
- Severity classification
- Suggested fix with remediation code
- File path and line number
- Effort to fix

## Severity Classification

- **Critical**: Remote code execution, authentication bypass, data breach
- **High**: Privilege escalation, stored XSS, SQL injection with limited scope
- **Medium**: CSRF, reflected XSS, information disclosure
- **Low**: Missing security headers, verbose errors, minor configuration issues

Flag findings exploitable without authentication.

## Scope Overrides

None — uses default scope detection.
