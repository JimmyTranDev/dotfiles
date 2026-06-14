---
name: specify-engage
description: Specify skill for engagement analysis — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`engage-`

## Skills to Load

- **strategy-engager**: Hook model, habit loops, dual process theory, friction reduction, persuasion principles
- **ui-designer**: Component architecture and UX patterns
- **ui-gamification**: Points, XP, levels, achievements, streaks, progression systems
- **ui-animator**: Animation patterns for engagement feedback
- **ui-accessibility**: Ensure engagement doesn't sacrifice accessibility (optional)
- **code-follower**: Match existing patterns (optional)

## Agents to Launch

None required.

## Analysis Categories

- **Onboarding friction**: Time to first value, registration walls, empty states, cognitive load on first visit — apply the first-time user flow pattern (Entry → Immediate value → Micro-commitment → First success → Reward → Next action)
- **Habit loop design**: Identify cue, craving, response, and reward for each core user action — find missing or weak phases and suggest strengthening them
- **Friction audit**: Walk through key user flows and score each step (0-4 friction scale) — flag anything scoring 3+ as blocking and suggest fixes using progressive disclosure, smart defaults, and recognition over recall
- **Retention mechanics**: Evaluate streak systems, variable rewards, progress visualization, social proof, and commitment escalation — suggest missing retention patterns appropriate to the product type
- **Persuasion alignment**: Check whether Cialdini's principles (social proof, reciprocity, commitment, scarcity, authority, unity) are applied ethically and effectively
- **Cognitive bias opportunities**: Identify where anchoring, loss aversion, default effect, endowment effect, peak-end rule, and IKEA effect could improve user decisions without dark patterns

## Severity Classification

Rank by impact-to-effort ratio:
- **Quick wins**: Small effort, high engagement impact
- **High-impact projects**: Large effort but transformative
- **Ethical concerns**: Flag fabricated scarcity, fake social proof, punitive mechanics, dark patterns

## Scope Overrides

None — uses default scope detection.
