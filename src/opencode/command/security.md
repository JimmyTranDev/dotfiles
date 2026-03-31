---
name: security
description: Scan code for security vulnerabilities and provide exact fixes with exploit scenarios
---

Usage: /security [scope or description]

Scan the specified code for security vulnerabilities, classify severity, show exploit scenarios, and provide exact fixes.

$ARGUMENTS

1. Understand the scope:
   - If the user specifies files or directories, focus the scan on those
   - If the user describes a concern (e.g., "auth flow", "API endpoints"), locate the relevant code
   - If no scope is given, scan the entire project focusing on entry points, auth, data handling, and external inputs

2. Load the **security** skill and scan systematically:
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
   - **Exact fix** with code that remediates the issue

4. Prioritize and report:
   - Rank findings by severity (Critical > High > Medium > Low)
   - Group related vulnerabilities together
   - Highlight any critical or high severity issues that need immediate attention

5. Ask the user which vulnerabilities to fix using the question tool with `multiple: true`, then apply the selected fixes

6. Load applicable skills and delegate to specialized agents — maximize parallelism per the Parallelization section in AGENTS.md:

   Skills to load (load all applicable skills in a single parallel batch):
   - **security**: Always load for vulnerability categories, severity classification, and remediation patterns
   - **npm-vulnerabilities**: Load when the project uses npm/node to check dependency vulnerabilities
   - **follower**: Always load to match existing codebase conventions when applying fixes

   Agents to delegate to:
   - **auditor**: Primary agent — scans code for vulnerabilities and provides fixes
   - **reviewer**: Launch after fixes are applied to verify they don't introduce new issues
