---
name: comm-adr-writer
description: Architecture Decision Records covering template structure, status lifecycle, consequences, alternatives, and team review workflow
---

## ADR Template

```markdown
# ADR-{NUMBER}: {TITLE}

## Status

{STATUS}

## Date

{YYYY-MM-DD}

## Context

{What is the issue or force driving this decision? What constraints exist?}

## Decision

{What is the change that we're proposing or have agreed to implement?}

## Consequences

### Positive
- {Benefit 1}
- {Benefit 2}

### Negative
- {Trade-off 1}
- {Trade-off 2}

### Neutral
- {Side effect that is neither positive nor negative}

## Alternatives Considered

### {Alternative 1}
- Description: {What was considered}
- Pros: {Why it was attractive}
- Cons: {Why it was rejected}

### {Alternative 2}
- Description: {What was considered}
- Pros: {Why it was attractive}
- Cons: {Why it was rejected}

## References

- {Link to RFC, discussion, PR, or external resource}
```

## Status Lifecycle

```
Proposed → Accepted → Implemented
    ↓         ↓
 Rejected  Deprecated → Superseded by ADR-{N}
```

| Status | Meaning |
|--------|---------|
| Proposed | Under discussion, not yet decided |
| Accepted | Decision made, not yet implemented |
| Implemented | Decision applied in codebase |
| Deprecated | No longer relevant but was valid |
| Superseded | Replaced by a newer ADR |
| Rejected | Considered but not adopted |

## File Organization

```
docs/
└── adr/
    ├── 0001-use-typescript.md
    ├── 0002-choose-postgresql.md
    ├── 0003-adopt-event-sourcing.md
    ├── 0004-use-kubernetes.md
    └── template.md
```

### Naming Convention
- `{NNNN}-{kebab-case-title}.md`
- Sequential numbering, never reuse numbers
- Title summarizes the decision (verb + noun)

## Writing Guidelines

### Context Section
- State the problem, not the solution
- Include relevant constraints (team size, timeline, budget, existing tech)
- Mention what triggered the decision
- Reference related ADRs if applicable
- Keep factual — no opinions in Context

### Decision Section
- Start with "We will..." or "We have decided to..."
- Be specific and unambiguous
- State the scope (what it applies to, what it doesn't)
- Include implementation constraints if relevant

### Consequences Section
- Be honest about trade-offs (every decision has negative consequences)
- Include operational impact (monitoring, on-call, deployment)
- Note team skill gaps or learning curves
- Identify risks and mitigation strategies
- Think about: cost, performance, maintainability, hiring, vendor lock-in

### Alternatives Section
- Include at least 2 alternatives (including "do nothing" when applicable)
- Be fair to rejected alternatives — state real pros
- Explain why each was rejected relative to the chosen option
- Link to spikes, benchmarks, or POCs if they exist

## Decision Criteria Framework

When evaluating alternatives, score against relevant criteria:

| Criterion | Weight | Option A | Option B | Option C |
|-----------|--------|----------|----------|----------|
| Team expertise | High | ★★★ | ★★ | ★ |
| Performance | Medium | ★★ | ★★★ | ★★★ |
| Maintenance cost | High | ★★★ | ★★ | ★ |
| Vendor lock-in | Low | ★★★ | ★ | ★★ |
| Community support | Medium | ★★★ | ★★★ | ★★ |

## Team Review Workflow

### 1. Draft
- Author writes ADR with status "Proposed"
- Include all sections except final consequences may be tentative
- Open PR with ADR file

### 2. Review
- Tag relevant stakeholders (tech leads, affected teams)
- Allow 3-5 business days for async review
- Reviewers comment on: missing alternatives, hidden consequences, unclear context
- Schedule synchronous discussion for contentious decisions

### 3. Decide
- Reach consensus or escalate to tech lead/architect
- Update status to "Accepted" or "Rejected"
- Add decision date
- Merge PR

### 4. Implement
- Reference ADR number in implementation PRs
- Update status to "Implemented" when fully applied
- Add implementation notes if approach deviated from plan

### 5. Supersede
- When revisiting a decision, create new ADR
- Update old ADR status to "Superseded by ADR-{N}"
- New ADR references old one in Context section

## When to Write an ADR

### Always Write ADR For
- Choosing a database, framework, or language
- Defining API contracts or protocols
- Selecting hosting/infrastructure platform
- Establishing coding standards or patterns
- Major architectural changes (monolith → microservices)
- Security-critical decisions (auth strategy, encryption)
- Decisions that are expensive to reverse

### Skip ADR For
- Library version upgrades (unless major breaking change)
- Bug fixes
- Implementation details within an existing pattern
- Decisions that are trivially reversible
- Team preferences with no architectural impact

## Quality Checklist

- [ ] Title clearly states the decision (not the problem)
- [ ] Context explains WHY without prescribing HOW
- [ ] Decision is specific enough to act on
- [ ] At least 2 alternatives documented with fair pros/cons
- [ ] Negative consequences honestly acknowledged
- [ ] Status and date are current
- [ ] Relevant stakeholders have reviewed
- [ ] Referenced from implementation code/PRs
- [ ] Follows sequential numbering

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Writing ADR after implementation | Write before or during, never retroactively justify |
| No alternatives section | Always include what else was considered |
| Only positive consequences | Every decision has trade-offs — be honest |
| Too long (> 2 pages) | Focus on decision, link to detailed analysis |
| Too vague ("use best practices") | Be specific: which practices, why, how |
| Never updating status | Part of definition of done for stories |
| ADR written by one person in isolation | Decisions need team input and review |
| Conflicting active ADRs | Supersede old ones explicitly |
