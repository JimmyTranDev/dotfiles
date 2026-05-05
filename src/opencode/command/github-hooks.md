---
name: github-hooks
description: Set up GitHub Actions workflows that trigger OpenCode actions via n8n webhooks
---

Usage: /github-hooks $ARGUMENTS

$ARGUMENTS

Set up or manage GitHub webhook integrations that trigger OpenCode commands automatically via GitHub Actions and n8n.

## Available Hooks

| GitHub Event | Action | OpenCode Command |
|-------------|--------|-----------------|
| PR opened | Auto-review the PR | `/review <PR-URL>` |
| PR comment added | Auto-respond or triage | `/triage-comments <PR-URL>` |
| PR checks failed | Investigate and fix | `/fix-checks <PR-URL>` |
| PR approved | Auto-merge if ready | `/merge` |

## Setup Workflow

1. Parse `$ARGUMENTS`:
   - If "setup" or "init" — create the GitHub Actions workflow file
   - If "list" — show configured hooks
   - If "add <event>" — add a new hook for the specified event
   - If "remove <event>" — remove a hook

2. For setup, create `.github/workflows/opencode-hooks.yml`:
   - Trigger on the configured events (pull_request, issue_comment, etc.)
   - Send a webhook to the n8n instance with event payload
   - Include the PR URL, event type, and relevant context

3. Provide n8n workflow template instructions:
   - Webhook receiver node
   - Filter by event type
   - Execute OpenCode command via SSH or API

## GitHub Actions Workflow Template

```yaml
name: OpenCode Hooks
on:
  pull_request:
    types: [opened, synchronize]
  issue_comment:
    types: [created]
  check_suite:
    types: [completed]

jobs:
  notify:
    runs-on: ubuntu-latest
    steps:
      - name: Send to n8n
        run: |
          curl -X POST "${{ secrets.N8N_WEBHOOK_URL }}" \
            -H "Content-Type: application/json" \
            -d '{
              "event": "${{ github.event_name }}",
              "action": "${{ github.event.action }}",
              "pr_url": "${{ github.event.pull_request.html_url }}",
              "repo": "${{ github.repository }}"
            }'
```

## Rules

- Never commit secrets directly — use GitHub repository secrets for webhook URLs
- The n8n webhook URL must be stored in `N8N_WEBHOOK_URL` repository secret
- This command creates workflow files but does NOT set up the n8n side — provide instructions only
