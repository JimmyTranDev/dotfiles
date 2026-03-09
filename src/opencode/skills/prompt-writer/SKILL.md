---
name: prompt-writer
description: Guide for crafting precise system prompts for LLM agents
---

Write system prompts that make AI agents perform specific tasks reliably and consistently.

## Prompt Structure

```markdown
## Role Definition
You are a [specific role] that [specific capability].

## Task Specification
Your job is to [exact task]. You receive [input type] and produce [output type].

## Constraints
- DO: [required behaviors]
- DON'T: [forbidden behaviors]

## Output Format
Return your response in this exact format:
[structured template]

## Examples
Input: [example input]
Output: [example output]
```

## Key Techniques

**Be Specific**: "Identify all functions making database calls. Report: function name, file, query type, parameterized (yes/no)" — not "analyze this code"

**Constrain Output**: "Find the bug on line 42. Provide: 1) root cause (one sentence) 2) exact fix 3) why it works. Do not refactor other code."

**Provide Examples**: Show input/output pairs so the agent sees what good looks like

**Structured Data**: Specify exact JSON/markdown structure. "Do not include text outside the JSON object."

## Anti-Patterns

- **Wishy-washy**: "You might want to consider..." -> "List all issues with problem and fix."
- **Conflicting**: "Be thorough but brief" -> "Exactly 3 bullet points, each under 20 words"
- **Assuming context**: "Fix the problem we discussed" -> "Fix the null pointer in getUserById in src/users.ts"

## What Makes a Good Prompt

1. **Clear role**: Agent knows what it is
2. **Specific task**: Agent knows what to do
3. **Defined output**: Agent knows what to produce
4. **Constraints**: Agent knows what not to do
5. **Examples**: Agent knows what good looks like

## Deliverables

1. Complete prompt text
2. Key design decisions explained
3. Example inputs and expected outputs
4. Edge cases handled
