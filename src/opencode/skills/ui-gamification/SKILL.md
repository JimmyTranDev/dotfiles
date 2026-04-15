---
name: ui-gamification
description: Game mechanics for web and mobile apps including points, XP, levels, achievements, streaks, leaderboards, progression systems, and reward loops
---

## Core Loop

```
Action -> Reward -> Motivation -> Action
```

Every gamification system is built on this loop. The user performs an action, receives a reward (intrinsic or extrinsic), which motivates the next action. Design the loop first, then choose mechanics.

## Mechanics Reference

| Mechanic | Purpose | Best For | Risk |
|----------|---------|----------|------|
| Points/XP | Quantify progress | Any trackable action | Inflation if uncapped |
| Levels | Gate content, show growth | Long-term engagement | Grind fatigue if spacing is wrong |
| Achievements/Badges | Celebrate milestones | Exploration, mastery | Meaningless if too easy |
| Streaks | Build habits | Daily engagement | Anxiety, punishes absence |
| Leaderboards | Social competition | Competitive users | Demotivates bottom 90% |
| Progress bars | Visualize completion | Onboarding, goals | Abandonment if too slow |
| Quests/Challenges | Direct behavior | Feature discovery | Feels forced if irrelevant |
| Unlockables | Reward exploration | Content-rich apps | Frustration if gated too hard |
| Multipliers | Reward intensity | Time-limited events | Devalues base rewards |
| Loot/Random rewards | Surprise and delight | Retention hooks | Feels manipulative if overused |

## Points & XP System Design

### XP Curve Formula

```ts
const xpForLevel = (level: number): number =>
  Math.floor(100 * Math.pow(level, 1.5))
```

| Level | XP Required | Cumulative XP |
|-------|-------------|---------------|
| 1 | 100 | 100 |
| 2 | 283 | 383 |
| 5 | 1,118 | 3,292 |
| 10 | 3,162 | 13,196 |
| 20 | 8,944 | 53,518 |
| 50 | 35,355 | 341,902 |

### XP Award Guidelines

| Action Type | XP Range | Example |
|-------------|----------|---------|
| Trivial | 1-10 | Viewing content, clicking |
| Easy | 10-50 | Completing a form, first interaction |
| Medium | 50-200 | Finishing a lesson, submitting work |
| Hard | 200-500 | Completing a project, passing a test |
| Epic | 500-2000 | Major milestone, multi-day challenge |

### Anti-Farming Rules

- Cap repeatable action XP per time window
- Diminishing returns on repeated identical actions
- Require diversity of actions for bonus XP
- Time-gate high-value rewards

## Achievement System

### Achievement Categories

| Category | Trigger | Example |
|----------|---------|---------|
| First-time | First completion of action | "First Steps" — complete onboarding |
| Cumulative | Reach count threshold | "Century" — 100 tasks completed |
| Streak | Consecutive days/actions | "On Fire" — 7-day streak |
| Speed | Complete within time limit | "Speed Demon" — finish in under 1 min |
| Collection | Gather all items in a set | "Completionist" — unlock all themes |
| Secret | Hidden until unlocked | "Easter Egg" — find hidden feature |
| Social | Involve other users | "Mentor" — help 10 users |
| Mastery | Demonstrate skill | "Perfectionist" — 100% accuracy |

### Achievement Data Model

```ts
interface Achievement {
  id: string
  name: string
  description: string
  icon: string
  category: AchievementCategory
  tier: "bronze" | "silver" | "gold" | "platinum"
  xpReward: number
  condition: AchievementCondition
  secret: boolean
  unlockedAt?: Date
}

interface AchievementCondition {
  type: "count" | "streak" | "speed" | "collection" | "compound"
  metric: string
  threshold: number
  timeWindow?: number
}
```

### Tier Progression

Design achievements in tiers so users always have the next goal visible:

| Tier | Threshold Pattern | XP Multiplier |
|------|-------------------|---------------|
| Bronze | 1x (e.g., 10) | 1x |
| Silver | 5x (e.g., 50) | 2x |
| Gold | 25x (e.g., 250) | 5x |
| Platinum | 100x (e.g., 1000) | 10x |

## Streak System

### Streak Design Rules

- Define a clear action that counts (e.g., "complete at least 1 task")
- Use calendar days, not 24h windows (timezone-aware)
- Provide a grace period or streak freeze to reduce anxiety
- Show current streak prominently but don't punish breaks harshly
- Reward milestone streaks (7, 30, 100 days) with bonus XP or badges

### Streak Recovery Patterns

| Pattern | Description | Best For |
|---------|-------------|----------|
| Freeze | User spends currency to preserve streak | Monetized apps |
| Grace period | 1 missed day doesn't break streak | Habit-building |
| Decay | Streak reduces by 1 instead of resetting | Reducing anxiety |
| Weekend skip | Weekends don't count | Work/productivity apps |

## Leaderboard Design

### Types

| Type | Scope | Reset | Best For |
|------|-------|-------|----------|
| Global all-time | Everyone | Never | Showcasing top users |
| Weekly/monthly | Everyone | Periodic | Keeping competition fresh |
| Friends | Social graph | Varies | Social motivation |
| Cohort | Users who joined same period | Never | Fair comparison |
| Percentile | Relative ranking | Rolling | Large user bases |

### Anti-Demoralization

- Show user's local rank (users nearby in ranking) not just top 10
- Use percentile-based tiers ("Top 10%") instead of raw position
- Separate leaderboards by skill level or join date
- Highlight personal bests alongside global ranks

## Progress System

### Visual Progress Patterns

| Pattern | Use When |
|---------|----------|
| Linear bar | Single metric, clear start/end |
| Circular/ring | Dashboard widget, compact space |
| Steps/milestones | Multi-phase process |
| Map/path | Journey metaphor, nonlinear content |
| Skill tree | Branching progression, unlocks |

### Onboarding Checklist

```ts
interface OnboardingStep {
  id: string
  label: string
  completed: boolean
  xpReward: number
  order: number
}
```

- Keep to 5-7 steps maximum
- Show completion percentage
- Award bonus XP for completing all steps
- Each step should demonstrate a core feature

## Notification & Feedback

### When to Notify

| Event | Notification Type | Urgency |
|-------|-------------------|---------|
| Achievement unlocked | Toast + animation | Immediate |
| Level up | Full-screen celebration | Immediate |
| Streak milestone | Toast | Immediate |
| Streak at risk | Push/banner | Preventive |
| Leaderboard position change | Badge/indicator | Passive |
| New challenge available | Dot indicator | Low |

### Celebration Hierarchy

| Event Significance | Animation |
|--------------------|-----------|
| Minor (XP gain, small badge) | Subtle toast, counter increment |
| Medium (achievement, streak milestone) | Animated toast with icon, confetti burst |
| Major (level up, rare achievement) | Full-screen overlay, particle effects |
| Epic (max level, legendary badge) | Extended celebration, shareable moment |

## Reward Psychology

### Intrinsic vs Extrinsic

| Intrinsic (Sustainable) | Extrinsic (Short-term) |
|-------------------------|------------------------|
| Mastery and skill growth | Points, XP, currency |
| Autonomy and choice | Badges, trophies |
| Purpose and meaning | Leaderboard rank |
| Social connection | Unlockable content |
| Curiosity satisfaction | Discounts, prizes |

Prioritize intrinsic motivators — extrinsic rewards should amplify, not replace, the core value of the product.

### Variable Reward Schedule

- Fixed rewards for predictable actions (task completion)
- Variable rewards for exploration (random bonus XP, surprise badges)
- Escalating rewards for sustained engagement (streak multipliers)
- Social rewards for collaborative actions (team bonuses)

## Anti-Patterns

- Gamification that replaces a broken core experience
- Punishing users for not engaging (negative streaks, public shame)
- Pay-to-win mechanics in non-game contexts
- Overwhelming users with too many systems at once
- Leaderboards that only motivate the top 1%
- Achievements for trivial actions that feel patronizing
- Dark patterns disguised as game mechanics (artificial urgency, loss aversion manipulation)
- Infinite progression with no meaningful milestones

## Implementation Checklist

- [ ] Core loop identified (action -> reward -> motivation)
- [ ] XP curve tested for first 10 levels (not too fast, not too slow)
- [ ] Achievements span multiple categories and tiers
- [ ] Streak system includes grace period or recovery
- [ ] Leaderboards segmented to avoid demoralization
- [ ] Progress visualization matches the mental model
- [ ] Celebration intensity matches event significance
- [ ] Notifications are non-intrusive and respect user attention
- [ ] Intrinsic motivators prioritized over extrinsic
- [ ] Anti-farming measures in place for repeatable rewards
- [ ] System tested with new users (onboarding) and power users (endgame)
