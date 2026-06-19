---
name: architecture-decision
description: Evaluate technical options with tradeoff analysis and write an ADR to architecture/
---

Usage: /architecture-decision $ARGUMENTS

$ARGUMENTS

Evaluate a technical decision with structured tradeoff analysis and record the outcome as an Architecture Decision Record (ADR) in the project's `architecture/` folder.

## Workflow

1. Load the **comm-adr-writer** skill. Also load in parallel: **strategy-system-design** (for architectural tradeoff analysis), **strategy-pragmatic-programmer** (for orthogonality and reversibility assessment), **strategy-criticize** (for devil's advocate analysis of each option).

2. Parse `$ARGUMENTS` to understand the decision context:
   - What problem needs solving?
   - What options are being considered?
   - What constraints exist?

3. If the question is unclear, ask clarifying questions:
   - What are the requirements and constraints?
   - What options have been considered so far?
   - What's the timeline and reversibility?

4. For each option, analyze:
   - **Pros**: Benefits, strengths, alignment with goals
   - **Cons**: Risks, drawbacks, limitations
   - **Effort**: Implementation complexity and timeline
   - **Reversibility**: How hard is it to change later?
   - **Team impact**: Learning curve, hiring implications, ecosystem

5. Present the analysis as a comparison table and provide a recommendation with rationale

6. After the user confirms the decision:
   - Create `architecture/` directory at project root if it doesn't exist
   - Write the ADR file following the format from the **comm-adr-writer** skill
   - Name the file with a sequential number and kebab-case title: `architecture/NNN-<title>.md`
   - Determine the next number from existing files in `architecture/`

## Rules

- Always present multiple options — never recommend without showing alternatives
- Be explicit about assumptions
- Include "do nothing" as an option when applicable
- Record the decision even if it's "we chose not to decide yet"
