---
name: strategy-criticize
description: Systematic criticism framework covering devil's advocate analysis, assumption surfacing, failure mode analysis, severity classification, and constructive feedback patterns
---

## Criticism Process

1. **Steel-man first** — articulate the strongest version of the idea before attacking it
2. **Surface assumptions** — list every implicit assumption the idea depends on
3. **Challenge each assumption** — ask "what if this isn't true?" for each one
4. **Run failure modes** — pre-mortem analysis of how this could fail
5. **Classify findings** — severity and likelihood for each issue
6. **Offer alternatives** — don't just criticize, suggest better approaches

## Assumption Surfacing

For any idea, plan, or implementation, extract assumptions across these categories:

| Category | Questions to Ask |
|----------|-----------------|
| **User behavior** | Will users actually do what we expect? What if they don't? |
| **Scale** | Does this work at 10x current load? 100x? Where does it break? |
| **Dependencies** | What external systems does this rely on? What if they're unavailable? |
| **Timeline** | Is the estimated effort realistic? What could take longer than expected? |
| **Data** | Are we assuming data is clean, complete, and correctly formatted? |
| **Team** | Does this require skills the team doesn't have? Knowledge that isn't documented? |
| **Environment** | Are we assuming specific infrastructure, tools, or configurations? |
| **Requirements** | Are we solving the right problem? Could the requirements change? |

## Failure Mode Analysis (Pre-Mortem)

Imagine the project has failed. Work backwards to identify causes:

| Failure Category | What to Look For |
|-----------------|-----------------|
| **Technical failure** | Architectural flaws, scalability limits, integration breakdowns, data corruption, security breaches |
| **Process failure** | Scope creep, missed deadlines, blocked dependencies, communication gaps, unclear ownership |
| **User failure** | Users don't adopt, can't figure out the UI, use it wrong, find workarounds, prefer alternatives |
| **Business failure** | Doesn't solve the actual problem, costs more than the value it provides, market moved on |
| **Operational failure** | Can't deploy, can't monitor, can't debug, can't roll back, on-call burden too high |

## Devil's Advocate Framework

For each claim or decision, systematically argue the opposite:

1. **State the claim** — "We should use X because Y"
2. **Invert the reasoning** — "What if Y isn't actually true?"
3. **Find counter-examples** — "When has this approach failed before?"
4. **Identify hidden costs** — "What are we giving up by choosing this?"
5. **Propose the alternative** — "What would we do instead if X weren't an option?"

## Criticism Categories

| Category | What It Covers | Cross-Reference |
|----------|---------------|-----------------|
| **Feasibility** | Can this actually be built with available resources and timeline? | — |
| **Scalability** | Will this work at 10x, 100x scale? Where are the bottlenecks? | — |
| **Maintainability** | Can someone else understand and modify this in 6 months? | Load **code-quality** skill |
| **Security** | What attack vectors does this introduce or leave unaddressed? | Load **security** skill |
| **Usability** | Will the target users be able to use this effectively? | — |
| **Cost** | Is the implementation and operational cost justified by the value? | — |
| **Correctness** | Are there logical flaws, impossible states, or missing edge cases? | Load **code-logic-checker** skill |
| **Soundness** | Are there suspicious patterns or things that look accidentally wrong? | Load **code-soundness** skill |
| **Simplicity** | Is this more complex than it needs to be? What could be removed? | — |
| **Reversibility** | Can we undo this decision if it turns out wrong? What's the rollback cost? | — |

## Severity Classification

| Severity | Definition | Action |
|----------|-----------|--------|
| **Critical** | Blocks the project or causes data loss/security breach if not addressed | Must fix before proceeding |
| **High** | Significant negative impact on quality, performance, or user experience | Should fix before shipping |
| **Medium** | Noticeable issue that affects maintainability or developer experience | Fix in this iteration if time allows |
| **Low** | Minor concern, nitpick, or theoretical risk with low probability | Document for future consideration |

## Constructive vs Destructive Criticism

| Constructive | Destructive |
|-------------|-------------|
| "This approach has a race condition when X and Y happen simultaneously. Using a mutex here would prevent it." | "This code is bad." |
| "The current design couples the auth layer to the database. Introducing a repository interface would allow swapping storage backends." | "You shouldn't have done it this way." |
| "If the API returns 500, the retry loop runs indefinitely. Adding a max retry count with exponential backoff would make this resilient." | "This will crash in production." |

### Pattern for Constructive Criticism

```
[Observation] — what you see, stated factually
[Impact] — why it matters, what goes wrong
[Suggestion] — specific alternative or fix
```

## Red Team Thinking

When evaluating security, resilience, or adversarial scenarios:

1. **Identify the assets** — what are we protecting? Data, uptime, user trust?
2. **Map the attack surface** — where can an adversary interact with the system?
3. **Enumerate threat actors** — who would attack this? Script kiddies, competitors, insiders?
4. **Find the weakest link** — what's the easiest thing to exploit?
5. **Chain attacks** — can multiple low-severity issues combine into a high-severity exploit?
6. **Assess blast radius** — if this is compromised, what else falls?

## Output Format

Present criticism as a structured report:

```
## Steel-Man Summary
[Best version of the idea/plan being critiqued]

## Findings

### [Finding Name] — [Severity]
**Category**: [from Criticism Categories]
**Observation**: [What you see]
**Impact**: [Why it matters]
**Suggestion**: [Specific alternative]

### [Finding Name] — [Severity]
...

## Summary
- Critical: N findings
- High: N findings
- Medium: N findings
- Low: N findings

## Top 3 Recommendations
1. [Most impactful improvement]
2. [Second most impactful]
3. [Third most impactful]
```
