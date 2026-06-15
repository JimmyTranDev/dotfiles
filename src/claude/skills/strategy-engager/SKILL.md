---
name: strategy-engager
description: Behavioral psychology for product engagement covering hook model, habit loops, dual process theory, UX friction reduction, persuasion principles, cognitive biases, virality frameworks, and ethical engagement patterns
---

## Hook Model

Based on Hooked (Eyal).

| Phase | Question | Techniques |
|-------|----------|------------|
| **Trigger** | What brings the user back? | External: push notifications, emails, social mentions. Internal: boredom, anxiety, FOMO, curiosity |
| **Action** | What's the simplest behavior in anticipation of reward? | Reduce effort (Fogg's B=MAT: Behavior = Motivation × Ability × Trigger), minimize steps, leverage existing mental models |
| **Variable Reward** | Does the reward satisfy yet leave wanting more? | Rewards of the tribe (social validation), rewards of the hunt (material/information), rewards of the self (mastery/competence) |
| **Investment** | What does the user put in that improves the next cycle? | Data, content, followers, reputation, skill — stored value that makes the product better with use |

### Internal Trigger Development

The goal is to move users from external triggers (notifications) to internal triggers (emotions/routines):

| Stage | Trigger Type | Example |
|-------|-------------|---------|
| New user | External — push notification | "You have a new message" |
| Returning user | External — habit cue | Morning routine, app icon on home screen |
| Habitual user | Internal — emotional | Feeling bored → opens app without thinking |

### Investment Loop

Each cycle of the hook should load the next trigger:

| Investment Type | How It Loads the Next Trigger | Example |
|----------------|-------------------------------|---------|
| Content creation | Others respond → notification → next trigger | Post a comment → get replies |
| Data entry | Personalization improves → product becomes more valuable | Rate preferences → better recommendations |
| Social connection | Followers create obligations → social triggers | Follow users → their activity triggers return visits |
| Skill building | Competence creates identity → internal trigger | Learn features → "I'm a power user" |

## Habit Loop Framework

Based on Atomic Habits (Clear) and The Power of Habit (Duhigg).

| Phase | Question | Techniques |
|-------|----------|------------|
| **Cue** | What triggers the user to open the app? | Time-based triggers, location triggers, emotional triggers, preceding-action triggers |
| **Craving** | What desire does this create? | Identity reinforcement ("be the kind of person who..."), curiosity gaps, streak protection |
| **Response** | How easy is it to take action? | Two-minute rule (make it trivially easy), reduce steps to under 3, progressive disclosure |
| **Reward** | What makes the user feel satisfied? | Variable rewards, progress visualization, social validation, completion dopamine |

### Habit Stacking

Attach new behaviors to existing routines: "After I [existing habit], I will [new behavior]."

| Existing Routine | Stacked Behavior | Example |
|-----------------|------------------|---------|
| Morning coffee | Daily check-in | Dashboard opens with morning summary |
| End of work day | Review/reflect | Prompt to log daily progress |
| After completing a task | Explore next | Suggest related content or next step |

### Environment Design

Make the desired action the path of least resistance:

| Principle | Application |
|-----------|-------------|
| Pre-fill defaults | Smart defaults that match most users' intent |
| Surface at the right time | Show the right action when context demands it |
| Hide friction-adding options | Collapse advanced settings, show on demand |
| Reduce decision points | Fewer choices = faster action |

### Habit Formation Timeline

| Day Range | Phase | Strategy |
|-----------|-------|----------|
| 1-7 | Activation | Minimize friction, maximize early wins, celebrate first actions |
| 7-30 | Routine building | Streak mechanics, reminders, identity reinforcement |
| 30-90 | Consolidation | Variable rewards, social proof, increasing commitment |
| 90+ | Maintenance | Refresh mechanics, new challenges, community involvement |

## Dual Process Theory

Based on Thinking, Fast and Slow (Kahneman).

| System | Characteristics | Design Implications |
|--------|----------------|---------------------|
| **System 1** (fast) | Automatic, intuitive, effortless, emotional, always on | Default interactions should target System 1 — visual, familiar, requiring no deliberation |
| **System 2** (slow) | Deliberate, logical, effortful, lazy, easily fatigued | Minimize System 2 demands — every time the user has to think, you risk losing them |

### Designing for System 1

| Principle | Application | Example |
|-----------|-------------|---------|
| Visual over textual | Icons, colors, and spatial layout communicate faster than words | Red badge = urgent, green checkmark = done |
| Familiarity bias | Reuse patterns users already know | Standard nav placement, conventional button styles |
| Emotional priming | First impression sets the frame for all subsequent decisions | Warm onboarding tone → user feels safe to explore |
| Cognitive ease | Fluent, simple presentation increases trust and liking | Clean typography, high contrast, short sentences |

### System 2 Budget

Users have a limited daily budget of System 2 effort. Every decision, form field, and unfamiliar UI element spends from this budget:

| Action | System 2 Cost | Mitigation |
|--------|--------------|------------|
| Choosing between options | High | Smart defaults, reduce to 2-3 choices |
| Reading instructions | High | Eliminate — make it self-evident |
| Entering data | Medium | Auto-fill, progressive collection |
| Learning new UI patterns | High | Use conventions, provide inline hints |
| Confirming destructive actions | Low (worthwhile) | Keep — this friction is valuable |

### Heuristics and Biases for Product Design

| Heuristic | How It Affects Users | Design Application |
|-----------|---------------------|-------------------|
| Availability heuristic | Recent/vivid events feel more likely | Show recent activity, success stories prominently |
| Representativeness | Users judge by surface similarity | Make important features look important |
| Framing effect | Same info, different presentation → different decisions | Frame features as gains ("save 2 hours") not neutral descriptions |
| Status quo bias | Users stick with defaults | Set defaults to the most beneficial option |
| Sunk cost | Past investment drives continued use | Show users their accumulated history, data, progress |

## Virality Framework

Based on Contagious (Berger).

### STEPPS Principles

| Principle | Core Idea | Product Application |
|-----------|-----------|-------------------|
| **Social Currency** | People share things that make them look good | Shareable achievements, exclusive access, insider knowledge |
| **Triggers** | Top-of-mind means tip-of-tongue | Associate product with frequent environmental cues (time of day, routine, location) |
| **Emotion** | High-arousal emotions drive sharing (awe, excitement, anger, anxiety) | Design moments that provoke awe or excitement, not just satisfaction |
| **Public** | Built to show, built to grow — observable behavior gets copied | Make usage visible (badges, status indicators, public profiles) |
| **Practical Value** | People share useful things | Package features as shareable tips, templates, or tools others can use |
| **Stories** | Narratives carry ideas as passengers | Embed product value in user success stories, not feature lists |

### Virality Loops

| Loop Type | Mechanism | Example |
|-----------|-----------|---------|
| Organic | Product use naturally creates exposure | Shared documents show brand, sent messages include link |
| Incentivized | Reward for inviting others | Referral credits, unlocked features for invites |
| Social proof | Visible usage attracts new users | Activity feeds, "X people are using this", public leaderboards |
| Content-driven | User-generated content reaches non-users | Shareable reports, public portfolios, embeddable widgets |

### Designing Shareable Moments

| Moment | Why It's Shareable | How to Enable |
|--------|-------------------|---------------|
| First achievement | Social currency — user feels proud | One-tap share with pre-formatted message |
| Milestone reached | Social currency + practical value | Auto-generated summary card with stats |
| Surprising result | Emotion (awe) + social currency | Highlight the unexpected, make it visual |
| Helpful discovery | Practical value + stories | "Share this tip" with context preserved |

## Friction Reduction

Based on Don't Make Me Think (Krug) and The Design of Everyday Things (Norman).

### Core Principles

| Principle | Rule |
|-----------|------|
| Affordances | Every interactive element visually communicates what it does before interaction |
| Signifiers | Visual cues (arrows, underlines, color changes) map to learned conventions |
| Progressive disclosure | Show only what's needed now, reveal complexity as the user advances |
| Recognition over recall | Visible options, recent items, smart defaults instead of forcing memory |
| Error prevention | Constrain inputs, confirm destructive actions, make undo easy |
| Krug's law | If something requires instructions, redesign it |

### Friction Audit Checklist

| Friction Type | Detection Signal | Fix |
|---------------|-----------------|-----|
| Cognitive load | User needs to read instructions | Simplify to self-evident |
| Choice overload | More than 3-5 options presented | Reduce, group, or default |
| Dead ends | User completes action with no next step | Always suggest the next action |
| Registration walls | Requiring signup before value delivery | Delay signup until after first value moment |
| Input fatigue | Long forms or manual data entry | Auto-fill, smart defaults, progressive collection |
| Context switching | User must leave current view to complete action | Inline editing, modals, slide-overs |
| Ambiguous labels | Button/link text doesn't predict outcome | Use specific verbs ("Save draft" not "Submit") |
| Missing feedback | User acts but nothing visibly changes | Immediate visual confirmation of every action |

### Friction Scoring

| Score | Level | Criteria |
|-------|-------|----------|
| 0 | Frictionless | User completes without thinking |
| 1 | Minor | Requires one pause or decision |
| 2 | Moderate | Requires reading or choosing among options |
| 3 | High | Requires multiple steps, context switching, or learning |
| 4 | Blocking | User is likely to abandon |

## Persuasion Principles

Based on Influence (Cialdini) and Predictably Irrational (Ariely).

### Cialdini's Principles

| Principle | Application | Example |
|-----------|-------------|---------|
| **Social Proof** | Show that others are doing it | "X people did this today", activity feeds, user counts |
| **Scarcity** | Limited availability creates urgency | Expiring streaks, limited-time features — must be real |
| **Reciprocity** | Give value first, then ask | Free trial, free content, then upgrade prompt |
| **Commitment & Consistency** | Start small, escalate gradually | One-click action first, then deeper engagement |
| **Authority** | Expert endorsement builds trust | Data-backed claims, trust badges, expert testimonials |
| **Liking** | Familiarity and personalization | Conversational tone, personalized content |
| **Unity** | Shared identity creates belonging | "Fellow developers", "our community", group identity |

### Cognitive Bias Toolkit

| Bias | Ethical Application | Anti-Pattern |
|------|--------------------|-|
| **Anchoring** | Show premium plan first so standard feels reasonable | Inflating the anchor price dishonestly |
| **Loss aversion** | Frame progress as something to protect ("don't lose your streak") | Fabricating losses that don't exist |
| **Default effect** | Pre-select the option most users want | Pre-selecting expensive options to trick users |
| **Decoy effect** | Add a third option that clarifies the best choice | Creating confusing pricing to obscure the real cost |
| **Endowment effect** | Let users invest effort before asking for payment | Holding user data hostage |
| **Zero-price effect** | Free tier as entry point creates disproportionate attraction | Bait-and-switch after free period |
| **Peak-end rule** | Make the final moment of any flow memorable and positive | Ending on an error or upsell |
| **IKEA effect** | Users value things they helped create | Forcing unnecessary customization |

## Engagement Metrics

| Metric | What It Measures | Target Signal |
|--------|-----------------|---------------|
| DAU/MAU ratio | Stickiness | > 0.2 is good, > 0.5 is exceptional |
| Day 1/7/30 retention | Habit formation stages | Benchmark varies by category |
| Time to first value | Onboarding friction | Under 60 seconds ideal |
| Session frequency | Habit strength | Increasing over first 30 days |
| Feature adoption rate | Discovery effectiveness | > 20% of eligible users |
| Activation rate | Users reaching "aha moment" | Define per product, track obsessively |
| Churn signals | At-risk detection | Decreasing session frequency, skipped streaks |

## Onboarding Patterns

| Pattern | When to Use | Key Rule |
|---------|-------------|----------|
| Progressive | Complex products | Teach one thing per session, not everything at once |
| Guided tour | Visual products | Keep to 3-5 steps max, let users skip |
| Learning by doing | Tool products | First task is the tutorial |
| Empty state | Content products | Show what filled state looks like, guide toward it |
| Checklist | Multi-feature products | 5-7 items, show progress, reward completion |

### First-Time User Flow

```
Entry → Immediate value preview → Micro-commitment (1 click) → First success → Reward → Suggest next action
```

Never: Entry → Registration wall → Long form → Empty dashboard → Figure it out

## Ethical Guardrails

| Rule | Reason |
|------|--------|
| Scarcity must be real | Fabricated urgency destroys trust permanently |
| Social proof must be honest | Fake counts are detectable and brand-damaging |
| Opting out must be easy and obvious | Dark patterns create resentment and legal risk |
| Engagement must create genuine user value | Addiction without value is exploitation |
| No punitive mechanics | Never shame or guilt users for disengaging |
| Disclose persuasion in consumer-facing copy | Transparency builds long-term trust |

## What This Skill Does NOT Cover

- Game mechanics implementation (points, XP, levels, achievements, leaderboards) — load the **ui-gamification** skill
- UI component architecture and visual design — load the **ui-designer** skill
- Animation and micro-interaction implementation — load the **ui-animator** skill
