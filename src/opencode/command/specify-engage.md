---
name: specify-engage
description: Analyze product engagement and suggest behavioral improvements to increase retention and reduce friction and write spec to `spec/`
---

Usage: /specify-engage [scope or focus area]

Analyze the project's user-facing flows and suggest engagement improvements — habit formation, friction reduction, and persuasion techniques grounded in behavioral science.

$ARGUMENTS

1. Understand the project (run independent commands in parallel):
   - Explore the project structure, entry points, and key modules to understand what the project does
   - Run `git log --oneline -30` to understand recent development direction and momentum
   - Read key config files, READMEs, or AGENTS.md to understand the project's purpose and audience

2. Load skills: **strategy-engager**, **ui-designer**, **ui-gamification**, **ui-animator**, and optionally **ui-accessibility**, **code-follower**. Analyze the project for engagement opportunities across these categories:
   - **Onboarding friction**: Time to first value, registration walls, empty states, cognitive load on first visit — apply the first-time user flow pattern (Entry → Immediate value → Micro-commitment → First success → Reward → Next action)
   - **Habit loop design**: Identify cue, craving, response, and reward for each core user action — find missing or weak phases and suggest strengthening them
   - **Friction audit**: Walk through key user flows and score each step (0-4 friction scale) — flag anything scoring 3+ as blocking and suggest fixes using progressive disclosure, smart defaults, and recognition over recall
   - **Retention mechanics**: Evaluate streak systems, variable rewards, progress visualization, social proof, and commitment escalation — suggest missing retention patterns appropriate to the product type
   - **Persuasion alignment**: Check whether Cialdini's principles (social proof, reciprocity, commitment, scarcity, authority, unity) are applied ethically and effectively
   - **Cognitive bias opportunities**: Identify where anchoring, loss aversion, default effect, endowment effect, peak-end rule, and IKEA effect could improve user decisions without dark patterns

3. For each opportunity:
   - Give it a short, clear name
   - Describe the current state and the behavioral science principle it violates or underutilizes in 1-2 sentences
   - Estimate effort (small, medium, large) and impact (high, medium, low)
   - Suggest where in the codebase it would fit and which existing patterns to follow
   - Cite the specific framework (Habit Loop, Friction Audit, Cialdini, Cognitive Bias Toolkit) backing the recommendation

4. Present findings:
   - Group by category
   - Within each category, rank by impact-to-effort ratio (quick wins first, then high-impact projects)
   - Highlight the top 3 "best bang for buck" improvements across all categories
   - Flag any ethical guardrail concerns (fabricated scarcity, fake social proof, punitive mechanics, dark patterns)

5. Write findings to a spec file using the `engage-` prefix per the `specify-*` conventions in AGENTS.md.
