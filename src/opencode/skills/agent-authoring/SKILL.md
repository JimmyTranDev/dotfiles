---
name: agent-authoring
description: How to write effective OpenCode agent definitions with proper structure, clear scope, and actionable instructions
---

## What Agents Are

Agents are specialized AI subagents invoked via the Task tool or `@` mention. Each agent is a markdown file in `~/.config/opencode/agent/` (global) or `.opencode/agent/` (project). The filename becomes the agent name.

## File Format

```markdown
---
name: agent-name
description: One-line summary of what this agent does and when to use it
mode: subagent
---

Opening identity sentence: "You [verb] [what]." — establishes role immediately.

## Section 1: What You Do / What You [Verb]
## Section 2: How You Work / Process
## Section 3: Output Format (if structured output needed)
## Section 4: What You Don't Do (guardrails)

Closing tagline: punchy, memorable, action-oriented.
```

## Required Frontmatter

| Field | Rule |
|-------|------|
| `name` | Lowercase, matches filename without `.md` |
| `description` | 5-20 words, starts with a role noun, explains when to use it |
| `mode` | `subagent` for Task-tool agents, `primary` for tab-switchable agents |

## Description Writing

The description is the single most important line. It determines whether the orchestrating agent picks this agent for a task.

**Pattern**: `<Role noun> that <primary action> [and <secondary action>]`

Good:
- "Bug fixer for known, reproducible issues — traces from symptom to root cause and applies minimal surgical fixes"
- "Code reviewer that catches bugs, identifies design issues, and provides actionable feedback"

Bad:
- "Helps with bugs" (too vague, no differentiation)
- "An agent that reviews code and finds issues and suggests improvements and checks security" (run-on, unfocused)

## Body Structure

### Opening Identity Sentence
One sentence. Present tense. "You [verb] [what]." Sets the agent's entire personality and scope.

### Scope Sections
Use `##` headers. Common patterns:
- **"What You [Verb]"** — enumerated list of capabilities with bold category labels
- **"How You Work" / "Process"** — numbered steps for the agent's workflow
- **"Output Format"** — exact template the agent should produce (use code blocks)
- **"What You Don't Do"** — explicit guardrails as bullet list

### Code Examples
Include inline code examples showing patterns the agent should recognize or produce. Keep them short (3-8 lines). Use real-world patterns, not toy examples.

### Closing Tagline
One line. Imperative mood. Reinforces the agent's core behavior.
- "Find the bug. Fix the bug. Move on."
- "Measure. Fix. Prove."
- "Consistency is the goal. Match what exists."

## Differentiation

When two agents overlap in scope, add a "When to Use X (vs Y)" section at the top of each:

```markdown
## When to Use Fixer (vs Solver)

**Use fixer when**: There's a specific error message, a failing test, a stack trace.
**Use solver when**: The problem is vague, spans multiple systems, nobody knows what's wrong.
```

## Quality Checklist

- [ ] Description alone is enough for an orchestrator to decide when to use this agent
- [ ] Opening sentence establishes role without preamble
- [ ] Each section has a clear purpose — no filler
- [ ] Code examples use realistic patterns from actual codebases
- [ ] "What You Don't Do" prevents scope creep into other agents
- [ ] No duplication of content that belongs in skills (module structure, naming conventions, etc.)
- [ ] No comments in code examples
