---
name: comm-natural-speech
description: Natural speech patterns for PR comments, replies, and written communication in English and Norwegian — avoiding robotic, repetitive, or formulaic phrasing
---

## Core Principle

Write like a real developer talking to a colleague. Every message should feel like it came from a human who read the code, understood the context, and responded thoughtfully.

## Emoji Usage 🎯

Emojis add warmth and personality when used sparingly. Overuse makes replies feel like corporate Slack bots.

### Emoji Rules

| Rule | Example |
|------|---------|
| Max 1 emoji per reply | "Fixed! 👍" not "Fixed! 👍✅🎉🚀" |
| Place at end of sentence, not start | "Good catch, updated 🔧" not "🔧 Good catch, updated" |
| Never use emoji as the entire reply | "👍" alone is lazy — add words |
| Rotate emojis — don't repeat the same one | Vary across 👍 ✅ 🔧 💡 etc. |
| Skip emoji on serious/complex discussions | Disagreements and architecture debates stay emoji-free |

### Emoji Vocabulary

| Context | Emojis to Rotate |
|---------|-----------------|
| Fixed/done | 👍 ✅ 🔧 |
| Good catch | 👀 🎯 |
| Learned something | 💡 🧠 |
| Agreement | 👌 🤝 |
| Oops/oversight | 😅 🤦 |
| Norwegian casual | 👍 ✅ 🫡 |

### Emoji Anti-Patterns

| ❌ Avoid | Why |
|----------|-----|
| 🚀 on every reply | Overused, meaningless |
| 😊 or 🙂 | Feels passive-aggressive in code review |
| Emoji chains (👍✅🎉) | Cluttered, performative |
| 💯 | Corny |
| Same emoji on 3+ consecutive replies | Repetitive, obviously automated |

## Anti-Patterns to Avoid

| Robotic Pattern | Why It Fails |
|----------------|--------------|
| "Great catch!" on every comment | Repetitive, feels automated |
| "Addressed in abc123" | Generic, shows no understanding |
| "Thanks for the feedback, I've updated..." | Formulaic opener, every reply sounds the same |
| "Good point! I've gone ahead and..." | Same structure repeated = obviously AI |
| "As per your suggestion..." | Stiff, nobody talks like this |
| "I have implemented the requested change" | Passive, formal, robotic |
| Starting every reply with "Thanks" | Gratitude fatigue, loses meaning |
| "LGTM" as the only reply | Lazy, adds no value |

## Natural Reply Patterns

### Acknowledging and Fixing

Vary the opening. Pick from natural phrases and rotate:

- "Ah yeah, missed that — fixed now 👍"
- "You're right, that edge case was uncovered. Added a null check."
- "Ugh, good eye 👀 Refactored to use the existing helper instead."
- "Fair point — switched to `Optional.ofNullable` here."
- "Yep, makes sense. Pulled that into a shared util 🔧"
- "Completely overlooked this 😅 Should be solid now."

### Disagreeing Respectfully

- "I actually went with X here because [reason] — but open to changing if you feel strongly."
- "Thought about that, but [tradeoff]. What do you think?"
- "I'd lean toward keeping it as-is since [reason], but happy to discuss."
- "Hmm, I see the concern but I think [reason] outweighs it here."

### Asking for Clarification

- "Not sure I follow — do you mean X or Y?"
- "Want me to extract this into its own method, or just inline the logic?"
- "Are you thinking [interpretation A] or more like [interpretation B]?"

### Quick Acknowledgments (when the fix is trivial)

- "Fixed ✅"
- "Done 👍"
- "Yep, updated."
- "Good catch, fixed 🔧"
- "Ah right — done."

## Variation Techniques

### Sentence Starters

Never use the same opener for consecutive replies. Rotate across these categories:

| Category | Examples |
|----------|----------|
| Agreement | "Yeah", "Right", "Fair point", "Agreed", "Makes sense" |
| Realization | "Ah", "Oh right", "Missed that", "Didn't notice" |
| Action | "Fixed", "Updated", "Refactored", "Moved", "Extracted" |
| Casual | "Sure thing", "On it", "Yep" |

### Sentence Length

Mix short and long replies. Not every comment deserves a paragraph. Trivial fixes get one-liners. Complex discussions get 2-3 sentences max.

### Contractions

Always use contractions in English: "don't", "isn't", "I'll", "that's", "wouldn't". Formal English ("do not", "is not") sounds robotic in PR comments.

### Emoji Cadence

Don't add emoji to every reply. Aim for roughly every 2nd or 3rd reply having one. This keeps them feeling natural rather than systematic.

## Norwegian Patterns

### Tone

Norwegian workplace communication is direct, informal, and low-hierarchy. Drop formality even more than in English.

### Common Phrases

| Context | Norwegian |
|---------|-----------|
| Agreeing | "Ja, godt poeng 👍", "Stemmer", "Enig", "Jepp" |
| Fixed | "Fiksa ✅", "Ordna", "Rettet opp", "Fikset nå 🔧" |
| Realization | "Oi, den glemte jeg 😅", "Ah, ser det nå", "Helt rett" |
| Disagreeing | "Tenkte litt på det, men...", "Skjønner poenget, men..." |
| Asking | "Mener du X eller Y?", "Skal jeg heller...?" |
| Quick ack | "Gjort 👍", "Fiksa", "Oppdatert ✅" |

### Norwegian Anti-Patterns

| Avoid | Why |
|-------|-----|
| "Takk for tilbakemeldingen" | Too formal for PR comments |
| "Jeg har implementert endringen" | Stiff, bureaucratic Norwegian |
| "I henhold til din kommentar" | Nobody writes like this |
| "Vennligst se oppdateringen" | Email-speak, not PR-speak |

## Context-Aware Replies

### Read the Tone of the Reviewer

- If the reviewer is casual ("hmm this looks off"), match their casual tone
- If the reviewer is detailed and technical, respond with specifics
- If the reviewer asks a question, answer it directly before describing what you did
- If the reviewer uses emoji, feel free to match — if they don't, lean toward fewer

### Reference the Actual Code

Bad: "I've updated the code as suggested."
Good: "Switched from `forEach` to `map` — cleaner and avoids the mutation 👍"

Bad: "Fixed the null issue."
Good: "Added a guard clause at the top of `processPayment` — returns early if `account` is null."

### Thread Context

When replying in a thread with prior discussion:
- Don't repeat what was already said
- Reference the conclusion: "Going with option B then — extracted the validation into `validateAmount` ✅"
- If the thread evolved, acknowledge it: "After the discussion above, landed on..."

## Batch Reply Consistency

When replying to multiple comments in one session:
- Track which openers you've used — never repeat within 3 consecutive replies
- Vary reply length: short, medium, short, long, short
- If multiple comments ask for similar changes, it's fine to say "Same pattern as above — fixed here too."
- Track emoji usage — never use the same emoji on consecutive replies, and skip emoji entirely on some replies

## What This Skill Does NOT Cover

- Commit message formatting — see **git-workflows** skill
- Code review writing (as the reviewer) — see **review-frontend** or **review-backend** skills
- Spec and documentation writing — see **comm-doc-writer** and **comm-spec-writer** skills
