---
name: plan
description: General-purpose planning command that analyzes and produces a plan based on whatever the user asks
---

Usage: /plan <what to plan>

Analyze the project and produce a plan based on the user's request. This is the generic planning entry point — it adapts to whatever the user asks for.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand the tech stack and what the project does
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose, audience, and constraints

2. Interpret `$ARGUMENTS` to determine what the user wants planned:
   - If the request maps clearly to a specialized `/plan-*` command, follow that command's workflow:
     - Code quality → `/plan-quality`
     - Logic correctness → `/plan-logic`
     - Code review / bug hunting → `/plan-review`
     - UI/UX design → `/plan-design`
     - User engagement / retention → `/plan-engage`
     - Test coverage → `/plan-test`
     - New ideas / brainstorming → `/plan-innovate`
      - Practical user needs → `/plan-useful`
      - Developer tools / manual testing → `/plan-devtools`
      - Code security / vulnerability audit → `/plan-audit`
   - If the request spans multiple domains, combine the relevant `/plan-*` workflows and launch applicable agents in parallel
   - If the request is something else entirely (architecture migration, refactoring strategy, release plan, feature roadmap, etc.), create a custom plan tailored to what the user asked for

3. Load any skills relevant to the user's request in parallel. Delegate to specialized agents where applicable — launch independent agents in parallel.

4. For each item in the plan:
   - Give it a short, clear name
   - Describe it in 1-2 sentences
   - Include file paths and line numbers where applicable
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest which `/command` to run to execute it

5. Present the plan:
   - Do NOT apply any changes — this command is analysis and planning only
   - Group findings logically based on the request
   - Rank by impact-to-effort ratio within each group
   - Highlight the top 3-5 highest-priority items

6. Output findings directly in chat as the final response. If the user specifies an output destination (file path, format, etc.), write there instead.
   - When writing to a file, append a new section with a timestamp header (create the file if it doesn't exist)
