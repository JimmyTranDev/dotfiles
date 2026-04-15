---
name: strategy-innovate
description: Innovation frameworks, ideation techniques, feature brainstorming categories, and impact-effort evaluation for generating project improvement ideas
---

Structured approach to generating, evaluating, and prioritizing project ideas.

## Ideation Frameworks

| Framework | When to Use | How It Works |
|-----------|-------------|--------------|
| SCAMPER | Improving existing features | Substitute, Combine, Adapt, Modify, Put to other use, Eliminate, Reverse |
| Jobs-to-be-Done | Finding new features | "When [situation], I want to [motivation], so I can [outcome]" |
| Pain Point Mining | UX improvements | List user frustrations, rank by frequency and severity |
| Competitive Gap | Market positioning | Compare feature matrices, find unserved needs |
| Workflow Analysis | Automation opportunities | Map user steps, identify repetitive or error-prone ones |
| Constraint Removal | Breakthrough ideas | "What if [current limitation] didn't exist?" |

## SCAMPER Applied to Software

| Technique | Question | Example |
|-----------|----------|---------|
| Substitute | What component can be replaced with something better? | Replace polling with WebSockets |
| Combine | What features work better together? | Merge search and filter into unified query bar |
| Adapt | What can be borrowed from another domain? | Apply spaced repetition to onboarding |
| Modify | What can be enlarged, shrunk, or reshaped? | Progressive disclosure for complex forms |
| Put to other use | Can existing data serve a new purpose? | Use error logs for auto-generated FAQ |
| Eliminate | What can be removed without losing value? | Remove confirmation dialogs for undo-able actions |
| Reverse | What happens if the flow is inverted? | Let users start from output and work backward |

## Feature Categories

| Category | Focus | Questions to Ask |
|----------|-------|------------------|
| New features | Functionality that doesn't exist | What do users request? What do competitors have? |
| UX enhancements | Making existing features better | Where do users get stuck? What takes too many clicks? |
| Integrations | Connecting with other tools | What tools do users already use alongside this? |
| Automation | Eliminating manual work | What do users do repeatedly? What can be inferred? |
| Quality of life | Small high-impact touches | Better errors? Smarter defaults? Keyboard shortcuts? |
| Scaling | Preparing for growth | Plugin system? Config options? Multi-tenant? |
| Performance | Speed and efficiency | What's slow? What loads unnecessarily? |
| Accessibility | Broader user reach | Screen readers? Keyboard nav? Color contrast? |

## Impact-Effort Matrix

```
High Impact
    │
    │  Quick Wins        Major Projects
    │  (DO FIRST)        (PLAN CAREFULLY)
    │
    ├──────────────────────────────────
    │
    │  Fill-ins           Avoid
    │  (DO IF TIME)      (DEPRIORITIZE)
    │
    └──────────────────── Low Impact
   Low Effort          High Effort
```

### Effort Estimation

| Effort | Time | Scope |
|--------|------|-------|
| Small | < 1 day | Single file, config change, copy tweak |
| Medium | 1-3 days | New component, API endpoint, workflow change |
| Large | 1-2 weeks | New system, multi-component feature, migration |
| XL | 2+ weeks | Architecture change, new service, major refactor |

### Impact Evaluation

| Impact | Signal |
|--------|--------|
| High | Affects all users, removes major pain point, enables new use cases |
| Medium | Affects subset of users, improves existing workflow |
| Low | Cosmetic, edge case, affects few users |

## Idea Evaluation Checklist

- Does it solve a real problem users have today?
- Does it align with the project's core purpose?
- Can it be built with existing patterns and infrastructure?
- Is there a way to validate it before full implementation?
- Does it introduce maintenance burden proportional to its value?
- Can it be shipped incrementally?

## Idea Presentation Format

| Field | Content |
|-------|---------|
| Name | Short descriptive name (2-5 words) |
| Category | Which feature category it belongs to |
| Description | What it does and why users want it (1-2 sentences) |
| Effort | Small / Medium / Large / XL |
| Impact | High / Medium / Low |
| Entry point | Where in the codebase it would fit |
| Patterns | Which existing patterns to follow |
| Next step | Which `/command` to run to start |

## Common Innovation Sources

| Source | How to Mine It |
|--------|----------------|
| Error logs | Recurring errors reveal user pain points |
| Support tickets | Common questions reveal missing features or UX gaps |
| Usage analytics | Underused features need improvement or removal |
| Competitor analysis | Feature gaps and differentiation opportunities |
| User interviews | "What's the hardest part of using this?" |
| Code complexity | Complex code often means complex UX — simplify both |
| New platform APIs | Browser/OS/framework features that weren't available before |
| Adjacent tools | Features from tools users switch to/from |

## Anti-Patterns

- Building features nobody asked for
- Copying competitors without understanding why the feature works for them
- Adding complexity to satisfy edge cases
- Innovating in core flows that work fine (don't fix what isn't broken)
- Premature optimization disguised as innovation
- Feature creep — adding everything instead of doing a few things well
- Ignoring maintenance cost of new features
- Building for power users at the expense of new user experience
