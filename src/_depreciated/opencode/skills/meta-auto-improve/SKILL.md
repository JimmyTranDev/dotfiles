---
name: meta-auto-improve
description: Proactive improvement of OpenCode skills and commands — triggered after every task to fix inaccuracies, fill gaps, improve clarity, and remove outdated content
---

## When This Skill Applies

After completing ANY task that involves using a skill or command, evaluate whether that skill or command can be improved. This is proactive — do not wait for a bug or gotcha to surface. Look for improvement opportunities in every interaction.

## Trigger Conditions

Improve a skill or command when any of these are true:

| Condition | Example |
|-----------|---------|
| Inaccuracy | A code example uses wrong syntax or flags |
| Missing workflow | You had to figure out a multi-step process not documented |
| Outdated content | A tool's API has changed since the skill was written |
| Unclear instruction | You had to re-read or guess what a step meant |
| Missing edge case | A common scenario isn't covered |
| Wrong default | The skill recommends an approach that fails in practice |
| Redundant content | Two sections say the same thing |
| Missing cross-reference | A related skill should be mentioned but isn't |
| Incomplete example | Code block is missing context needed to use it |
| Command workflow gap | A command's steps skip something you had to do manually |

## What to Improve

### Skills

- Fix incorrect code examples, CLI flags, or API signatures
- Add workflows you discovered through trial-and-error
- Remove content that no longer applies (deprecated APIs, old patterns)
- Clarify ambiguous instructions with concrete examples
- Add missing gotchas and edge cases
- Improve table completeness (missing rows for common scenarios)
- Add cross-references to related skills where a reader would need them

### Commands

- Fix workflow steps that don't match actual tool behavior
- Add missing precondition checks or error handling steps
- Clarify argument parsing when `$ARGUMENTS` handling is ambiguous
- Add missing agent delegation or skill loading steps
- Fix incorrect skill/agent names referenced in the command
- Add edge cases the command doesn't handle (empty args, invalid input)

## Process

1. Identify what was wrong, missing, or unclear during the task
2. Read the relevant skill/command file
3. Make the minimal edit that fixes the issue — match existing format and style
4. If the improvement requires loading **meta-opencode-authoring** (e.g., restructuring a section, adding new frontmatter), load it first
5. Do NOT ask the user for permission — just improve it. The user has opted in by loading this skill.

## Scope Boundaries

| Do | Don't |
|----|-------|
| Fix factual errors | Rewrite entire skills for style preference |
| Add missing common workflows | Add niche one-off scenarios |
| Remove genuinely outdated content | Remove content you personally didn't use |
| Improve clarity of confusing steps | Add verbose explanations to concise skills |
| Add cross-references | Duplicate content across skills |
| Fix broken examples | Add examples for every possible variation |

## Relationship to meta-skill-learnings

The **meta-skill-learnings** skill covers reactive improvements — when you discover a bug pattern, gotcha, or anti-pattern during review/analysis. This skill (**meta-auto-improve**) is broader and proactive:

- **meta-skill-learnings**: "I found a new pattern to document"
- **meta-auto-improve**: "The existing documentation is wrong/incomplete/unclear — fix it"

Both can apply in the same task. Load **meta-skill-learnings** when you have a new insight to add. Use **meta-auto-improve** when existing content needs correction or enhancement.
