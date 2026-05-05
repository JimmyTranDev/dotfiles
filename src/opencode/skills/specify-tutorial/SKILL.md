---
name: specify-tutorial
description: Specify skill for tutorial spec generation — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`tutorial-`

## Skills to Load

- **code-follower**: Match existing codebase conventions
- Domain-relevant skills based on project type

## Agents to Launch

- **reviewer**: Verify proposed steps are correct, complete, and in the right order

## Analysis Categories

### Step Decomposition

Break work into small, logical steps where each step is:
- A single focused change (one function, one file modification, one configuration change)
- Ordered so each builds on the previous
- Independently understandable

### Per-Step Documentation

For each step:
- **What**: Short title describing the change
- **Why**: Why this step is needed and how it connects to the overall goal
- **Where**: File path and location within the file
- **Before**: Exact code that exists now (or "new file" if creating)
- **After**: Exact code it should become after the change
- **Explanation**: What changed between before and after — key differences and reasoning

### Presentation

- Number steps sequentially
- Include a summary at the top listing all steps
- After all steps, include a final summary of all files touched and cumulative effect

## Severity Classification

Not applicable — this is implementation planning, not issue finding.

## Scope Overrides

If the request is vague, ask clarifying questions before proceeding.
