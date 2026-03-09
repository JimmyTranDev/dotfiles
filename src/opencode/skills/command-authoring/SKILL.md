---
name: command-authoring
description: How to write effective OpenCode slash commands with clear workflows, argument handling, and agent delegation
---

## What Commands Are

Commands are slash-invoked prompts (`/command-name`) that execute a predefined workflow. Each command is a markdown file in `~/.config/opencode/commands/` (global) or `.opencode/commands/` (project). The filename becomes the command name.

## File Format

```markdown
---
name: command-name
description: One-line summary of what the command does
---

Opening instruction: what to do when the command runs.

1. First step with sub-bullets for details
2. Second step
3. ...

Agent delegation section (if applicable).

Important notes / constraints.
```

## Required Frontmatter

| Field | Rule |
|-------|------|
| `name` | Lowercase kebab-case, matches filename without `.md` |
| `description` | 5-15 words, starts with a verb, describes the user-facing action |

## Optional Frontmatter

| Field | Purpose |
|-------|---------|
| `agent` | Which agent executes the command (default: current agent) |
| `subtask` | `true` to force subagent invocation |
| `model` | Override the model for this command |

## Description Writing

Commands describe an action the user triggers, so descriptions start with a verb.

Good:
- "Create a well-formatted git commit with emoji prefix and conventional format"
- "Scan code for security vulnerabilities and provide exact fixes"

Bad:
- "Commit helper" (noun, not an action)
- "This command reviews code" (don't start with "This command")

## Body Structure

### Opening Instruction
One sentence or short paragraph stating what happens when the command runs. Written as a directive to the AI.

### Numbered Workflow Steps
Use `1. 2. 3.` numbered list. Each step is an action with sub-bullets for details, edge cases, and error handling.

Key patterns:
- **Scope determination**: "If the user specifies X, focus on that. If not, default to Y."
- **Precondition checks**: Verify tools exist, branches exist, files are staged, etc.
- **Error exits**: "If X is not found, notify the user and stop"
- **User confirmation gates**: "Ask the user to confirm before proceeding"

### Agent Delegation Section
List which agents to delegate to and when:

```markdown
Delegate to specialized agents where applicable:
- **follower**: Use first to learn codebase conventions
- **fixer**: Use for each identified bug
- **reviewer**: Use after all changes to verify correctness
```

### Constraints / Important Notes
A bullet list of hard constraints:
- What to include / exclude
- Files to ignore
- Safety checks (don't commit secrets, etc.)

## Arguments

Use `$ARGUMENTS` for the full argument string, or `$1`, `$2`, `$3` for positional args:

```markdown
Usage: /component $ARGUMENTS
Create a new React component named $ARGUMENTS.
```

## Shell Output Injection

Use `` !`command` `` to inject shell output into the prompt:

```markdown
Recent commits:
!`git log --oneline -10`
```

## Avoiding Duplication

Commands should not duplicate content that lives in skills. Reference skills instead:

Good: `Format: \`<emoji> <type>(<scope>): <description>\` — use the emoji mapping from the \`git-workflows\` skill.`

Bad: Copying the full emoji mapping table into the command file.

## Quality Checklist

- [ ] Description starts with a verb
- [ ] Steps are numbered and ordered logically
- [ ] Error cases are handled ("if not found, notify and stop")
- [ ] Agent delegation lists only agents that are actually relevant
- [ ] No duplication of content from skills or other commands
- [ ] Usage line shows argument syntax if arguments are accepted
