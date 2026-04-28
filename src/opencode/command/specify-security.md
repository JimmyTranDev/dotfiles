---
name: specify-security
description: Scan code for security vulnerabilities with exploit scenarios and severity classification and write spec to `spec/`
---

Usage: /specify-security [scope or description]

Scan the specified code for security vulnerabilities, classify severity, show exploit scenarios, and report findings without applying any fixes. Write all findings to a spec file.

$ARGUMENTS

1. Explore the project structure, entry points, and key modules to understand the tech stack and attack surface. Identify the framework, API layer, authentication system, and data storage approach.

2. Load skills: **security**, **code-follower**, **code-conventions**, and optionally **security-npm-vulnerabilities**. Scan systematically across these categories (only include categories that are relevant):
   - **Injection**: SQL injection, NoSQL injection, command injection, LDAP injection, XPath injection, template injection — string concatenation in queries, unsanitized user input passed to shell commands, eval/Function constructors, dynamic template rendering
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

3. For each vulnerability found, document:
   - **What's wrong** and which category it falls under
   - **How it's exploitable** with a concrete attack scenario
   - **Severity** classification (Critical / High / Medium / Low)
   - **Suggested fix** with code showing how to remediate the issue
   - File path and line number
   - Effort to fix (small, medium, large)

4. Present the analysis:
   - Group findings by category from step 2
   - Within each category, rank by severity (Critical > High > Medium > Low)
   - Highlight any critical or high severity issues that need immediate attention
   - Flag any findings that could be exploited without authentication

5. Launch agents in parallel:
   - **auditor**: Deep scan for exploitable vulnerabilities with specific attack vectors
   - **reviewer**: Analyze code patterns for correctness issues that overlap with security (race conditions, error handling, input validation)

6. Write findings to a spec file using the `security-` prefix per the `specify-*` conventions in AGENTS.md.
