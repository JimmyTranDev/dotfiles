---
name: specify-security
description: Scan code for security vulnerabilities and report findings with exploit scenarios without making changes and write spec to `spec/security/`
---

Usage: /specify-security [scope or description]

Scan the specified code for security vulnerabilities, classify severity, show exploit scenarios, and report findings without applying any fixes. Write all findings to a spec file.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus the scan on those
   - If the user describes a concern (e.g., "auth flow", "API endpoints"), locate the relevant code
   - If no scope is given, scan the entire project focusing on entry points, auth, data handling, and external inputs

2. Load all applicable skills in parallel (**security**, **code-follower**, and optionally **security-npm-vulnerabilities**), then scan systematically:
   - Check every user input path for injection vulnerabilities
   - Verify authentication and authorization on all endpoints
   - Look for hardcoded secrets, credentials, and API keys
   - Check cryptographic usage for weak algorithms or static keys
   - Inspect error handling for data leakage
   - Review dependencies for known CVEs

3. For each vulnerability found, document:
   - **What's wrong** and which category it falls under
   - **How it's exploitable** with a concrete attack scenario
   - **Severity** classification (Critical / High / Medium / Low)
   - **Suggested fix** with code showing how to remediate the issue

4. Present the analysis:
   - Do NOT apply any changes — this command is analysis-only
   - Rank findings by severity (Critical > High > Medium > Low)
   - Group related vulnerabilities together
   - Highlight any critical or high severity issues that need immediate attention

5. Delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Agents to delegate to (launch independent agents in parallel):
   - **auditor**: Primary agent — scans code for vulnerabilities and classifies findings
   - **reviewer**: Verify vulnerability assessments are accurate

6. Write findings to a spec file:
   - Create the `spec/security/` directory if it doesn't exist
   - Choose the filename: if the user provided a scope description, convert it to kebab-case and use it as the filename (e.g., `auth-flow.md`); otherwise use a timestamp (`YYYY-MM-DDTHH-MM-SS.md`)
   - If a file with the chosen name already exists, append a timestamp suffix before the extension
   - Write all findings to the file: grouped by severity, with category, exploit scenario, severity classification, file location, and suggested fix for each item
   - Print a brief summary to chat: the spec file path, total findings count, and any critical/high severity items
