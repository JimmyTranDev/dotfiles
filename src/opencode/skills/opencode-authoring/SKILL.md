---
name: opencode-authoring
description: How to write OpenCode agents, commands, and skills with proper structure, frontmatter, descriptions, and content patterns
---

## Agents

### What Agents Are

Agents are specialized AI subagents invoked via the Task tool or `@` mention. Each agent is a markdown file in `~/.config/opencode/agent/` (global) or `.opencode/agent/` (project). The filename becomes the agent name.

### File Format

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

### Required Frontmatter

| Field | Rule |
|-------|------|
| `name` | Lowercase, matches filename without `.md` |
| `description` | 5-20 words, starts with a role noun, explains when to use it |
| `mode` | `subagent` for Task-tool agents, `primary` for tab-switchable agents |

### Description Writing

The description determines whether the orchestrating agent picks this agent for a task.

**Pattern**: `<Role noun> that <primary action> [and <secondary action>]`

Good:
- "Bug fixer for known, reproducible issues — traces from symptom to root cause and applies minimal surgical fixes"
- "Code reviewer that catches bugs, identifies design issues, and provides actionable feedback"

Bad:
- "Helps with bugs" (too vague, no differentiation)
- "An agent that reviews code and finds issues and suggests improvements and checks security" (run-on, unfocused)

### Body Structure

**Opening Identity Sentence** — one sentence, present tense. "You [verb] [what]." Sets the agent's personality and scope.

**Scope Sections** — use `##` headers:
- **"What You [Verb]"** — enumerated capabilities with bold category labels
- **"How You Work" / "Process"** — numbered steps for the workflow
- **"Output Format"** — exact template using code blocks
- **"What You Don't Do"** — explicit guardrails as bullet list

**Closing Tagline** — one line, imperative mood, reinforces core behavior:
- "Find the bug. Fix the bug. Move on."
- "Measure. Fix. Prove."
- "Consistency is the goal. Match what exists."

### Differentiation

When two agents overlap in scope, add a "When to Use X (vs Y)" section at the top of each:

```markdown
## When to Use Fixer (vs Reviewer)

**Use fixer when**: There's a specific error, failing test, stack trace, or vague cross-system problem to investigate.
**Use reviewer when**: Code is complete and you want a quality review for bugs, design issues, and maintainability.
```

### Quality Checklist

- [ ] Description alone is enough for an orchestrator to decide when to use this agent
- [ ] Opening sentence establishes role without preamble
- [ ] Each section has a clear purpose — no filler
- [ ] Code examples use realistic patterns from actual codebases
- [ ] "What You Don't Do" prevents scope creep into other agents
- [ ] No duplication of content that belongs in skills

---

## Commands

### What Commands Are

Commands are slash-invoked prompts (`/command-name`) that execute a predefined workflow. Each command is a markdown file in `~/.config/opencode/command/` (global) or `.opencode/command/` (project). The filename becomes the command name.

### File Format

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

### Required Frontmatter

| Field | Rule |
|-------|------|
| `name` | Lowercase kebab-case, matches filename without `.md` |
| `description` | 5-15 words, starts with a verb, describes the user-facing action |

### Optional Frontmatter

| Field | Purpose |
|-------|---------|
| `agent` | Which agent executes the command (default: current agent) |
| `subtask` | `true` to force subagent invocation |
| `model` | Override the model for this command |

### Description Writing

Commands describe an action the user triggers, so descriptions start with a verb.

Good:
- "Create a well-formatted git commit with emoji prefix and conventional format"
- "Scan code for security vulnerabilities and provide exact fixes"

Bad:
- "Commit helper" (noun, not an action)
- "This command reviews code" (don't start with "This command")

### Body Structure

**Opening Instruction** — one sentence or short paragraph stating what happens when the command runs, written as a directive to the AI.

**Numbered Workflow Steps** — `1. 2. 3.` list with sub-bullets for details, edge cases, and error handling:
- **Scope determination**: "If the user specifies X, focus on that. If not, default to Y."
- **Precondition checks**: Verify tools exist, branches exist, files are staged, etc.
- **Error exits**: "If X is not found, notify the user and stop"
- **User confirmation gates**: "Ask the user to confirm before proceeding"

**Agent Delegation Section** — list which agents to delegate to and when:

```markdown
Delegate to specialized agents where applicable:
- **reviewer**: Use first to review code for correctness
- **fixer**: Use for each identified bug
- **reviewer**: Use after all changes to verify correctness
```

**Constraints / Important Notes** — bullet list of hard constraints (inclusions, exclusions, safety checks).

### Arguments

Use `$ARGUMENTS` for the full argument string, or `$1`, `$2`, `$3` for positional args:

```markdown
Usage: /component $ARGUMENTS
Create a new React component named $ARGUMENTS.
```

### Shell Output Injection

Use `` !`command` `` to inject shell output into the prompt:

```markdown
Recent commits:
!`git log --oneline -10`
```

### Quality Checklist

- [ ] Description starts with a verb
- [ ] Steps are numbered and ordered logically
- [ ] Error cases are handled ("if not found, notify and stop")
- [ ] Agent delegation lists only agents that are actually relevant
- [ ] No duplication of content from skills or other commands
- [ ] Usage line shows argument syntax if arguments are accepted

---

## Skills

### What Skills Are

Skills are reusable knowledge documents loaded on-demand via the `skill` tool. Agents see a list of available skills (name + description) and can load the full content when relevant. Each skill lives at `skills/<name>/SKILL.md`.

### File Format

```markdown
---
name: skill-name
description: One-line summary of what knowledge this skill provides
---

## Section 1
Content organized by topic.

## Section 2
More content. Use tables, code blocks, and lists.
```

### Discovery Locations

- Global: `~/.config/opencode/skills/<name>/SKILL.md`
- Project: `.opencode/skills/<name>/SKILL.md`

Skills are auto-discovered — they do NOT need to be listed in `opencode.json`.

### Required Frontmatter

| Field | Rule |
|-------|------|
| `name` | 1-64 chars, lowercase alphanumeric, single-hyphen separators, matches directory name |
| `description` | 1-1024 chars, specific enough for an agent to decide when to load it |

### Optional Frontmatter

| Field | Purpose |
|-------|---------|
| `license` | License identifier (e.g., `MIT`) |
| `compatibility` | Tool compatibility (e.g., `opencode`) |
| `metadata` | String-to-string map for custom metadata |

### Description Writing

The description appears in the skill tool's available skills list. It must be specific enough for an agent to decide whether to load the skill.

Good:
- "Branch naming, commit conventions, PR workflows, and base branch strategy"
- "Shell scripting conventions for bash and zsh including error handling, naming, color output, and module patterns"

Bad:
- "Git stuff" (too vague, agent can't decide when to load it)
- "Everything you need to know about React" (too broad, no specifics)

### Content Principles

**Domain-Scoped** — each skill covers one domain. Don't mix unrelated topics.

**No Duplication Across Skills** — shared conventions belong in one skill. Before adding content, check: "Does this already exist in another skill?" If yes, don't repeat it.

**Actionable Over Theoretical** — include concrete patterns, code examples, decision trees, and lookup tables. Avoid paragraphs of theory.

Good:
```markdown
| Content | File |
|---------|------|
| TypeScript type/interface | `types.ts` |
| Constant, enum, or config value | `consts.ts` |
```

Bad:
```markdown
When organizing TypeScript modules, it's important to consider the separation
of concerns and ensure that each file has a single responsibility...
```

### Content Structure

Use `##` headers to organize by topic. Common patterns:
- **Tables** for lookup/reference data (naming conventions, emoji mappings, aliases)
- **Code blocks** for patterns and examples
- **Bullet lists** for rules and conventions
- **Decision trees** for "where does X go?" questions

### Quality Checklist

- [ ] Name matches directory name and passes regex `^[a-z0-9]+(-[a-z0-9]+)*$`
- [ ] Description lists specific topics covered (not just the domain name)
- [ ] Content is domain-scoped — no bleed into other skills
- [ ] No duplication of content from other skills
- [ ] Examples use realistic code, not toy examples
- [ ] Tables and code blocks preferred over prose

---

## Shared Rules

- **Name validation**: all names must match `^[a-z0-9]+(-[a-z0-9]+)*$` — lowercase alphanumeric with single hyphens, no leading/trailing/consecutive hyphens
- **No duplication**: commands should not duplicate skill content — reference skills instead. Skills should not duplicate other skills. Agents should not embed domain knowledge that belongs in skills.
- **Code examples**: keep them short (3-10 lines), realistic, from actual codebases — not toy examples

---

## Per-Project MCP Server Enablement

MCP servers in the global `opencode.json` can be set to `enabled: false` to avoid startup latency. Projects that need a specific server can override this in their project-level `.opencode/opencode.json`:

```json
{
  "mcp": {
    "server-name": {
      "enabled": true
    }
  }
}
```

Project-level config merges with global config — only the fields you specify are overridden. The server's `command`, `args`, and `env` from the global config are preserved; only `enabled` is flipped.

Use this pattern to keep global startup fast while enabling servers per-project as needed.

---

## Skill Dependency Conventions

OpenCode does not enforce skill dependencies in frontmatter. When a skill builds on or relates to another skill, declare the relationship in the skill's content:

**Pattern**: Reference related skills at the point where they are relevant, using bold skill names.

```markdown
## What This Skill Does NOT Cover

- Dependency vulnerability triage and npm audit workflows — see **npm-vulnerabilities** skill
- Infrastructure security — out of scope
```

```markdown
## Advanced Refactoring

For extracting repeated patterns into shared utilities, load the **deduplicator** skill.
For merging over-separated code, load the **consolidator** skill.
```

**Rules**:
- Reference skills by their exact name (the directory name / frontmatter `name`)
- Place references where a reader would naturally need the related skill
- Use "see **skill-name** skill" for cross-references in scope exclusion sections
- Use "load the **skill-name** skill" for cross-references in workflow sections
- Do not create circular dependencies between skills
