---
name: specify-deploy
description: Generate implementation specs for deployment and infrastructure changes in plans/
---

Usage: /specify-deploy [scope or description]

Analyze the project's deployment infrastructure and generate an implementation spec for changes or improvements.

$ARGUMENTS

1. Load the **tool-github-actions** skill
2. Detect the deployment stack by checking for Dockerfiles, CI workflows, cloud config files, and infrastructure-as-code
3. If no deployment configuration exists, note this as a greenfield deployment setup
4. Analyze the current deployment configuration for:
   - Build process and artifacts
   - CI/CD pipeline stages
   - Environment variables and secrets management
   - Health checks and monitoring
   - Scaling configuration
   - Rollback mechanisms
5. Based on the scope/description provided, identify what changes are needed
6. Generate an implementation spec covering:
   - Current state summary
   - Proposed changes with rationale
   - Dockerfile modifications (if applicable)
   - CI pipeline updates (if applicable)
   - Environment configuration changes
   - Rollback plan for each change
   - Testing strategy for infrastructure changes
   - Risk assessment
7. Write the spec to `plans/deploy-<descriptive-name>.md`
8. If the `plans/` directory does not exist, create it
9. Print a summary to chat: spec file path, key changes proposed, and risk level

Constraints:
- Do not apply any changes — this is spec generation only
- If scope is unclear or too broad, ask the user to narrow it down
- Always include a rollback plan for every proposed change
- Flag any changes that could cause downtime
