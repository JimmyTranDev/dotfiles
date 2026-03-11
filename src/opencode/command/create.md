---
name: create
description: Create a new command, skill, or agent by analyzing what type best fits the user's intent
---

Usage: /create <description of what you want to create>

Analyze the user's description and create the appropriate OpenCode extension (command, skill, or agent).

$ARGUMENTS

1. Determine the best extension type by evaluating the description against these criteria:

   | Type | Best When | Examples |
   |------|-----------|---------|
   | **Command** | The user wants a repeatable workflow triggered by `/name` — a sequence of steps, tool calls, and agent delegations | "a command that runs tests and fixes failures", "a command that sets up a new project" |
   | **Skill** | The user wants reusable reference knowledge that agents load on-demand — conventions, patterns, lookup tables, decision trees | "best practices for database migrations", "API design guidelines" |
   | **Agent** | The user wants a specialized persona with a distinct role, judgment, and scope — something that reasons independently about a domain | "an agent that reviews accessibility", "an agent that optimizes SQL queries" |

   Decision tree:
   - Is it a **step-by-step workflow** the user triggers? -> **Command**
   - Is it **reference knowledge** agents consult? -> **Skill**
   - Is it a **specialized role** that needs independent reasoning? -> **Agent**
   - If unclear, ask the user to clarify

2. Load the appropriate authoring skill:
   - Command -> load **command-authoring** skill
   - Skill -> load **skill-authoring** skill
   - Agent -> load **agent-authoring** skill

3. Check for conflicts:
   - Search existing commands, skills, and agents for overlapping names or functionality
   - If a conflict exists, notify the user and suggest either extending the existing one or picking a different name
   - If no conflict, proceed

4. Scaffold the extension:
   - **Command**: Create `~/.config/opencode/command/<name>.md` with proper frontmatter, usage line, numbered steps, agent delegation section, and constraints
   - **Skill**: Create directory `~/.config/opencode/skills/<name>/` and `SKILL.md` with frontmatter, organized sections using tables and code blocks
   - **Agent**: Create `~/.config/opencode/agent/<name>.md` with frontmatter (including `mode: subagent`), opening identity sentence, scope sections, and closing tagline

5. Validate the result:
   - Frontmatter fields are present and valid
   - Name follows kebab-case convention (`^[a-z0-9]+(-[a-z0-9]+)*$`)
   - Description is specific and actionable (verb-led for commands, role-led for agents, topic-led for skills)
   - No content duplicated from existing skills
   - No comments in code examples

6. Present the result to the user with a summary of what was created and why that type was chosen

Important:
- Always follow the conventions from the loaded authoring skill exactly
- Prefer concise, actionable content over lengthy explanations
- Use tables, code blocks, and bullet lists — avoid prose paragraphs
- Do not duplicate content that already exists in other skills or agents
- If the description is ambiguous between two types, ask the user before proceeding
