---
name: strategy-estimation
description: Estimation techniques covering story points, t-shirt sizing, PERT, cone of uncertainty, velocity tracking, and decomposition strategies
---

## Story Points

### Fibonacci Scale

| Points | Meaning |
|--------|---------|
| 1 | Trivial, no unknowns, < 1 hour |
| 2 | Simple, well-understood, few hours |
| 3 | Straightforward, minor complexity |
| 5 | Moderate complexity, some unknowns |
| 8 | Significant complexity, multiple components |
| 13 | Large, many unknowns, consider splitting |
| 21 | Too large — must be decomposed |

### What Story Points Measure
- Effort (how much work)
- Complexity (how hard to think through)
- Uncertainty (how many unknowns)
- NOT time — points are relative to each other

### Calibration
- Pick a well-understood 3-point story as reference
- Compare all other stories relative to reference
- Team must agree on reference stories
- Re-calibrate when team composition changes significantly

## T-Shirt Sizing

| Size | Typical Duration | When to Use |
|------|-----------------|-------------|
| XS | < 2 hours | Config change, copy update |
| S | Half day | Single file change, well-defined |
| M | 1-2 days | Multiple files, some investigation |
| L | 3-5 days | Cross-cutting, design decisions needed |
| XL | 1-2 weeks | Major feature, multiple services |
| XXL | > 2 weeks | Must be broken down further |

### Mapping to Story Points
- XS = 1, S = 2, M = 3-5, L = 8, XL = 13, XXL = 21+

## PERT (Three-Point Estimation)

### Formula
```
Expected = (Optimistic + 4 × Most Likely + Pessimistic) / 6
Standard Deviation = (Pessimistic - Optimistic) / 6
```

### Process
1. For each task, estimate three values:
   - **Optimistic (O)**: Everything goes perfectly, no surprises
   - **Most Likely (M)**: Normal conditions, typical interruptions
   - **Pessimistic (P)**: Significant obstacles, learning curve, rework
2. Calculate expected duration
3. Use standard deviation for confidence intervals:
   - 68% confidence: Expected ± 1 SD
   - 95% confidence: Expected ± 2 SD

### Example
| Task | O | M | P | Expected | SD |
|------|---|---|---|----------|-----|
| Auth integration | 2d | 4d | 10d | 4.7d | 1.3d |
| CRUD API | 1d | 2d | 4d | 2.2d | 0.5d |
| UI components | 3d | 5d | 9d | 5.3d | 1.0d |

## Cone of Uncertainty

| Phase | Estimate Range |
|-------|---------------|
| Initial concept | 0.25x - 4x |
| Approved product definition | 0.5x - 2x |
| Requirements complete | 0.67x - 1.5x |
| UI design complete | 0.8x - 1.25x |
| Detailed design complete | 0.9x - 1.1x |

### Implications
- Early estimates need wide ranges (communicate as ranges, not points)
- Narrow the cone by doing discovery/spike work before committing
- Re-estimate as uncertainty decreases
- Never give single-number estimates at early stages

## Velocity Tracking

### Calculating Velocity
- Velocity = total story points completed per sprint
- Use rolling average of last 3-5 sprints
- Exclude abnormal sprints (holidays, incidents)

### Using Velocity for Planning
```
Remaining points / Average velocity = Estimated sprints remaining
```

### Velocity Anti-Patterns
- Comparing velocity across teams
- Using velocity as performance metric
- Inflating points to appear productive
- Not accounting for capacity changes (vacations, new hires)

### Healthy Velocity Patterns
- Track trend over time (increasing = improving, stable = mature)
- Use range (low/avg/high) for forecasting
- Account for planned capacity: `Available velocity = Avg velocity × (Available days / Sprint days)`

## Decomposition Strategies

### Vertical Slicing
Split by user-visible functionality, not technical layers:
- BAD: "Build database schema" → "Build API" → "Build UI"
- GOOD: "User can create account" → "User can view profile" → "User can edit profile"

### INVEST Criteria for Good Stories
- **I**ndependent: Minimal dependencies on other stories
- **N**egotiable: Not a contract, open to discussion
- **V**aluable: Delivers value to user or business
- **E**stimable: Clear enough to estimate
- **S**mall: Completable in one sprint
- **T**estable: Clear acceptance criteria

### Decomposition Techniques
| Technique | When to Use |
|-----------|-------------|
| By workflow step | Multi-step processes |
| By business rule | Complex logic with variations |
| By data variation | Different entity types |
| By interface | Multiple platforms/consumers |
| By operation | CRUD operations |
| By performance | Base case vs optimized |
| By error handling | Happy path first, then edge cases |
| Spike + implementation | High uncertainty tasks |

### When to Split
- Story estimated > 8 points
- Story has multiple acceptance criteria that could ship independently
- Story spans multiple sprints
- Team can't agree on estimate (signals hidden complexity)

## Estimation Process

### Planning Poker Flow
1. Product owner presents story and acceptance criteria
2. Team asks clarifying questions
3. Each member selects estimate simultaneously
4. Reveal estimates — if consensus, move on
5. If divergent: highest and lowest explain reasoning
6. Re-vote (max 2 rounds, then take higher estimate)

### Estimation Checklist
- [ ] Requirements clear enough to estimate?
- [ ] Acceptance criteria defined?
- [ ] Dependencies identified?
- [ ] Technical approach discussed?
- [ ] Edge cases considered?
- [ ] Testing effort included?
- [ ] Deployment/migration effort included?
- [ ] Documentation effort included?

## Common Estimation Mistakes

| Mistake | Fix |
|---------|-----|
| Estimating only happy path | Add 30-50% for edge cases and testing |
| Ignoring integration effort | Account for API contracts, data migration |
| Anchoring on first number heard | Use simultaneous reveal (Planning Poker) |
| Confusing effort with duration | A 2-day task with blockers ≠ 2 calendar days |
| Not including code review time | Factor in review cycles and rework |
| Estimating without the team | Include everyone who will do the work |
| Single-number estimates early on | Always give ranges before detailed design |
| Never re-estimating | Update estimates as you learn more |

## Communicating Estimates

### To Stakeholders
- Always give ranges, not single numbers
- State confidence level: "80% confident it's 2-3 weeks"
- Call out assumptions explicitly
- Identify biggest risks that could blow estimates
- Offer trade-offs: "2 weeks for full feature, 1 week for MVP"

### Tracking Accuracy
- Compare estimated vs actual after each sprint
- Calculate estimation accuracy: `actual / estimated`
- Identify systematic biases (consistently over/under)
- Use historical accuracy to adjust future estimates
