---
name: security
description: Scan code for security vulnerabilities and provide exact fixes
---

Scan the specified code for security vulnerabilities and apply fixes.

Usage: /security [scope]

1. Determine the scope:
   - If the user specifies files, directories, or a feature, focus on those
   - If no scope is given, analyze recent changes via `git diff` against the base branch (prefer `develop`, fall back to `main`)
   - For full audit, scan the entire project

2. Delegate to the **auditor** agent to scan for:
   - Injection vulnerabilities (SQL, XSS, command injection, path traversal)
   - Authentication and authorization flaws
   - Secrets and credentials in code or config
   - Insecure dependencies
   - Data exposure (logging sensitive data, verbose error messages)
   - Missing input validation and sanitization

3. For each vulnerability found:
   - Classify severity (critical, high, medium, low)
   - Explain the attack vector
   - Provide an exact code fix

4. Load relevant skills and delegate to additional agents when applicable:

   Skills to load:
   - **convention-matcher**: Load to ensure fixes match codebase conventions

   Agents to delegate to:
   - **fixer**: Apply the security fixes to the codebase
   - **reviewer**: Verify fixes don't introduce regressions

5. After fixing:
   - Re-run the security scan to confirm vulnerabilities are resolved
   - Summarize findings by severity with before/after comparison
