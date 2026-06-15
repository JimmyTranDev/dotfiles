---
name: specify-deploy
description: Specify skill for deployment analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`deploy-`

## Skills to Load

- **tool-github-actions**: GitHub Actions workflow patterns

## Agents to Launch

None required.

## Analysis Categories

### Stack Detection

- Check for Dockerfiles, CI workflows, cloud config files, and infrastructure-as-code
- If no deployment configuration exists, note as greenfield deployment setup

### Deployment Configuration Analysis

- Build process and artifacts
- CI/CD pipeline stages
- Environment variables and secrets management
- Health checks and monitoring
- Scaling configuration
- Rollback mechanisms

### Spec Output Sections

- Current state summary
- Proposed changes with rationale
- Dockerfile modifications (if applicable)
- CI pipeline updates (if applicable)
- Environment configuration changes
- Rollback plan for each change
- Testing strategy for infrastructure changes
- Risk assessment

### Constraints

- Always include a rollback plan for every proposed change
- Flag any changes that could cause downtime

## Severity Classification

- **Critical**: Changes that could cause downtime or data loss
- **High**: Missing rollback mechanisms, exposed secrets
- **Medium**: Suboptimal configuration, missing health checks
- **Low**: Nice-to-have improvements

## Scope Overrides

If scope is unclear or too broad, ask the user to narrow it down.
