---
name: plan-audit
description: Analyze application code for security vulnerabilities and report findings without making changes
---

Usage: /plan-audit [scope or description]

Analyze the project's application code for security vulnerabilities — injection flaws, authentication weaknesses, authorization gaps, data exposure, and unsafe patterns — without making any changes. This focuses on code-level security, not package/dependency auditing (use `/pr-audit` for that).

$ARGUMENTS

Load the **security** and **conventions** skills in parallel.

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand the tech stack and attack surface
   - Run `git log --oneline -30` to understand recent development direction
   - Identify the framework, API layer, authentication system, and data storage approach
   - If the user specifies a scope, narrow analysis to those files or areas

2. If the user specifies a scope or focus area, narrow analysis to that. Otherwise analyze the full codebase.

3. Analyze the application code for security vulnerabilities across these categories (only include categories that are relevant):
   - **Injection**: SQL injection, NoSQL injection, command injection, LDAP injection, XPath injection, template injection. Look for string concatenation in queries, unsanitized user input passed to shell commands, eval/Function constructors, and dynamic template rendering with user data.
   - **Cross-site scripting (XSS)**: Reflected, stored, and DOM-based XSS. Look for `dangerouslySetInnerHTML`, `innerHTML`, `document.write`, unsanitized URL parameters rendered in HTML, missing output encoding, and user content rendered without escaping.
   - **Authentication**: Weak password policies, missing rate limiting on login, insecure token storage (localStorage for JWTs), missing token expiration, hardcoded credentials, insecure password comparison (timing attacks), missing MFA enforcement.
   - **Authorization**: Missing access control checks on API routes, IDOR (insecure direct object references), privilege escalation paths, missing role validation, client-side-only authorization checks, GraphQL queries that expose unauthorized data.
   - **Data exposure**: Sensitive data in logs, verbose error messages in production, API responses that include more fields than needed, missing field-level filtering, secrets in client-side bundles, PII in URLs or query parameters.
   - **CSRF and request forgery**: Missing CSRF tokens on state-changing endpoints, SameSite cookie misconfiguration, missing Origin/Referer validation, CORS misconfiguration allowing wildcard origins with credentials.
   - **Insecure cryptography**: Weak hashing algorithms (MD5, SHA1 for passwords), missing salt, hardcoded encryption keys, insecure random number generation (Math.random for security-sensitive values), deprecated TLS versions.
   - **Server-side request forgery (SSRF)**: User-controlled URLs passed to server-side fetch/request calls without validation, missing allowlist for outbound requests, URL redirect endpoints that follow arbitrary redirects.
   - **File handling**: Unrestricted file uploads (no type/size validation), path traversal in file operations, serving user-uploaded files without content-type validation, missing virus scanning.
   - **Session management**: Insecure session configuration, missing HttpOnly/Secure flags on cookies, session fixation, missing session invalidation on logout or password change, overly long session lifetimes.
   - **API security**: Missing input validation on API endpoints, missing rate limiting, mass assignment vulnerabilities, missing pagination limits, GraphQL depth/complexity limits, missing API versioning that could break security assumptions.
   - **Unsafe patterns**: Use of `eval`, `new Function`, `setTimeout/setInterval` with strings, prototype pollution vectors, regex denial of service (ReDoS), uncontrolled resource consumption.

4. For each finding:
   - Give it a short, clear name
   - Describe the vulnerability, how it could be exploited, and what the fix would look like
   - Classify severity: critical, high, medium, low
   - Estimate effort to fix (small, medium, large)
   - Include file paths and line numbers
   - Suggest which `/command` to run to address it (e.g., `/fix`, `/implement`, `/security`)

5. Delegate to specialized agents — launch independent agents in parallel:
   - **auditor**: Deep scan for exploitable vulnerabilities with specific attack vectors
   - **reviewer**: Analyze code patterns for correctness issues that overlap with security (race conditions, error handling, input validation)

6. Present findings:
   - Do NOT apply any changes — this command is analysis-only
   - Group by category from step 3
   - Within each category, rank by severity (critical first)
   - Highlight the top 3-5 most critical vulnerabilities that need immediate attention
   - Flag any findings that could be exploited without authentication

7. Output findings directly in chat as the final response. If the user specifies an output destination (file path, format, etc.), write there instead.
   - When writing to a file, append a new section with a timestamp header (create the file if it doesn't exist)
   - Include each item's file location, severity, description, and suggested `/command`
