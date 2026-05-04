---
name: deploy
description: Execute a guided deployment workflow with pre-checks, build, push, and verification
---

Usage: /deploy [environment]

Execute a structured deployment workflow including pre-flight checks, build, push, and post-deploy verification.

$ARGUMENTS

1. Detect the deployment configuration by checking for:
   - Dockerfile / docker-compose.yml
   - vercel.json / .vercel/
   - fly.toml
   - netlify.toml
   - railway.json
   - package.json deploy script
   - GitHub Actions deploy workflow
2. If no deployment config is found, notify the user and stop
3. Determine the target environment (default to production if not specified)
4. Run pre-deployment checks in parallel:
   - Verify no uncommitted changes: `git status --porcelain`
   - Verify branch is up to date with remote: `git fetch && git status`
   - Run tests: detect and execute the test command
   - Run build: detect and execute the build command
5. If any pre-check fails, report which check failed and stop
6. Ask the user for confirmation before proceeding with deployment
7. Execute the deployment:
   - Docker: build image and push to registry
   - Vercel: `vercel --prod` (or `vercel` for preview)
   - Fly: `fly deploy`
   - Custom: run the deploy script
8. After deployment, verify the health endpoint if one is configured or discoverable
9. Report deployment status: success or failure with relevant logs

Constraints:
- Always require user confirmation before the actual deploy step
- If any step fails, stop immediately and report the error
- Never force-push or deploy with uncommitted changes
- Never deploy to production without passing tests
