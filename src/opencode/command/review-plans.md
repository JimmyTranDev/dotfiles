---
name: review-plans
description: Review plan files one by one, presenting each decision with pros/cons for approval or denial
---

Usage: /review-plans $ARGUMENTS

Walk through plan/spec files and present every unresolved decision for individual approval or denial, with detailed context on why each decision matters.

$ARGUMENTS

1. Locate plan files:
   - If the user specifies a directory or files, use those
   - If no arguments provided, look for `plans/`, `spec/`, or `docs/` directories in the project root
   - If no plan files found, notify the user and stop
   - Read ALL plan files in parallel to understand the full scope

2. Extract decisions from each plan:
   - Scan each file for "Open Questions", "Resolved Questions", "TODO", "TBD", or any section containing unresolved choices
   - Also identify decisions that WERE made in the plan but deserve scrutiny — design choices, scope boundaries, technology picks, things included, and things excluded
   - Build a flat list of every individual decision point across all files

3. For each decision, prepare a detailed brief:
   - **Context**: What part of the system this affects and why the decision exists (1-2 sentences)
   - **Options**: List concrete options (not just "yes/no" — explain what each option means in practice)
   - **Pros/cons for each option**: Tangible tradeoffs — effort, risk, complexity, maintainability, user impact
   - **Recommendation**: State which option you'd pick and why, based on codebase context and engineering judgment
   - **When it matters**: Is this a blocking decision (changes architecture) or deferrable (cosmetic, can be changed later)?
   - **Impact if wrong**: What happens if this decision turns out to be incorrect — is it reversible?

4. Present decisions for review:
   - Go through ONE PLAN AT A TIME, in order of priority/risk
   - Within each plan, present decisions one at a time using the question tool
   - Each question should include the plan filename in the header for orientation
   - Group related decisions into a single question batch (max 5 per batch) when they're from the same plan
   - For each option, put the recommended choice first with "(Recommended)" suffix
   - Enable custom answers — the user may want an option not listed

5. After each plan's decisions are reviewed:
   - Immediately apply the approved changes to the plan file:
     - Move approved decisions from "Open Questions" to "Resolved Questions"
     - For denied decisions, keep them in "Open Questions" unchanged
     - For custom answers, add the user's answer to "Resolved Questions"
     - Remove tasks, sections, or content that the user explicitly rejected
   - Renumber any task lists if items were removed
   - Confirm the file was updated before moving to the next plan

6. After all plans are reviewed:
   - Print a summary table: plan name, decisions approved, decisions denied, decisions deferred
   - List any plans that are now fully resolved (no remaining open questions)
   - List any plans that still have unresolved questions
   - Suggest which `/command` to run next (e.g., `/implement` for the highest-priority fully-resolved plan)

Important:
- Never skip a decision — every open question and significant design choice must be presented
- Never auto-approve — every decision needs explicit user input
- If a decision in one plan affects another plan, mention the dependency when presenting it
- If the user says "skip" or dismisses a question, keep it as an open question — do not resolve it
- Plans with no open questions or decisions to review should be noted as "already resolved" and skipped
