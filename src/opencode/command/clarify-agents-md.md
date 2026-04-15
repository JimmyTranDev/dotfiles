---
name: clarify-agents-md
description: Read AGENTS.md and ask targeted clarifying questions to refine its rules and fill gaps
---

Usage: /clarify-agents-md $ARGUMENTS

Read the project's AGENTS.md and ask the user targeted clarifying questions about their conventions, preferences, and coding style to help refine the rules. If $ARGUMENTS specifies a path, use that AGENTS.md. Otherwise, use the repo root.

1. Load the **meta-agents-md** skill to understand AGENTS.md structure and content principles

2. **Read the existing AGENTS.md**:
   - If no AGENTS.md exists, tell the user to run `/improve-agents-md` first and stop
   - Parse the current sections, rules, and structure

3. **Scan the codebase for context** (run in parallel):
   - Identify the tech stack from package files (package.json, Cargo.toml, go.mod, etc.)
   - Read key config files (linter configs, tsconfig, formatters, CI pipelines)
   - Sample 3-5 representative source files to observe actual patterns
   - Check for subdirectory AGENTS.md files

4. **Identify gaps** by comparing what AGENTS.md covers against what the codebase reveals:

   | Category | What to Check |
   |----------|---------------|
   | **Naming** | Variable/function/file naming conventions, casing rules, prefix/suffix patterns |
   | **Architecture** | Module boundaries, import rules, dependency direction, layer restrictions |
   | **Error handling** | Try/catch patterns, error types, logging conventions, user-facing vs internal errors |
   | **Testing** | Test file placement, naming, framework, coverage expectations, what to mock |
   | **State management** | Where state lives, patterns used, reactivity model |
   | **API design** | Endpoint naming, request/response shapes, validation, versioning |
   | **Git workflow** | Branch naming, commit format, PR process, merge strategy |
   | **Performance** | Bundle size concerns, lazy loading rules, caching patterns |
   | **Accessibility** | ARIA patterns, keyboard nav requirements, a11y testing |
   | **Dependencies** | When to add new deps, approval process, version pinning |

5. **Generate clarifying questions**:
   - Focus on gaps where the codebase shows patterns that AGENTS.md doesn't document
   - Focus on areas where the codebase is inconsistent and a rule would help
   - Use the question tool with concrete options where possible (e.g., "Your codebase uses both camelCase and snake_case for X — which should be the rule?")
   - For each question, briefly explain what you observed and why the rule matters
   - Limit to 5-8 questions per round, prioritized by impact on agent behavior
   - Skip questions where AGENTS.md already has a clear rule

6. **After the user answers**:
   - Summarize the new rules as concise directives matching the existing AGENTS.md style
   - Show the proposed additions/changes to AGENTS.md
   - Ask for confirmation before writing
   - If there are more gaps to address, offer to run another round of questions

Do not modify AGENTS.md until the user explicitly confirms the proposed changes.
