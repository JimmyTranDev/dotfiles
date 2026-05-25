---
name: system-design
description: Generate a realistic system design problem, walk through solving it step-by-step, and save the solution to ~/notes
---

Usage: /system-design [$ARGUMENTS]

Generate a realistic system design interview problem, then guide the user through a structured solution. If `$ARGUMENTS` specifies a topic, use it; otherwise pick a random well-known system design problem.

## Output

Two tiers:

**Tier 1 (CLI output)**: Problem statement. Then each solution step is presented, the user answers, and you provide the model answer after each step. This is what the user sees interactively.

**Tier 2 (saved file)**: The full problem + solution written to `~/Programming/JimmyTranDev/notes/system-design/<topic>/<YYYY-MM-DD>.md`. Create directories if they don't exist.

## Workflow

### 1. Select or accept the topic

If `$ARGUMENTS` contains a system design topic (e.g., "Design a URL shortener", "Design Twitter"), use it directly. If empty or unrecognized, randomly select one from the problem pool below.

Pick from: Design a URL shortener (TinyURL), Design a rate limiter, Design a web crawler, Design a notification system, Design Instagram, Design Twitter, Design a chat system (WhatsApp/Messenger), Design YouTube, Design a proximity service (Yelp Nearby), Design a key-value store, Design a unique ID generator, Design a ticket booking system, Design a news feed system, Design a search autocomplete system, Design a distributed message queue, Design a pastebin, Design a consistent hashing system, Design a metrics/monitoring system.

### 2. Present the problem statement

Print a realistic system design problem statement including:
- **System**: what to build
- **Scope**: core features (functional requirements)
- **Scale**: approximate scale (DAU, QPS, storage, bandwidth)
- **Constraints**: non-functional requirements (latency, availability, consistency needs)

Then ask: "Ready to start the walkthrough?" with options: Yes, Let me try this one on my own (skip to save), Pick a different topic.

### 3. Walk through the solution step-by-step

For each step, present the question, let the user answer (or skip), then provide the model answer. Steps:

**Step 1 — Requirements Clarification**
Ask: "What clarifying questions would you ask the interviewer?" After user answers, provide a model list: functional requirements (core features, extended features), non-functional requirements (latency, availability, consistency, durability), capacity estimates.

**Step 2 — Back-of-the-Envelope Estimation**
Ask: "What are your rough capacity estimates?" After user answers, provide model estimates: DAU, read/write QPS, storage for 5 years, bandwidth, cache memory estimates. Show the math.

**Step 3 — Data Model / Schema**
Ask: "How would you model the data? What tables/collections would you create?" After user answers, show model schema with: tables/collections, key columns/fields, primary keys, indexes, estimated row sizes, SQL vs NoSQL choice with rationale.

**Step 4 — High-Level Design**
Ask: "What's your high-level architecture? What components do you need?" After user answers, describe the architecture: client/app, load balancers, API servers, services, databases, caches, object storage, CDN, async processing (queues/workers). Note: you cannot draw diagrams, but describe layers and data flow clearly in text.

**Step 5 — API Design**
Ask: "What REST/gRPC endpoints would you expose?" After user answers, show: endpoint paths, HTTP methods, request/response bodies, auth requirements, pagination, rate limiting.

**Step 6 — Deep Dive 1 (Critical Component)**
Identify the most architecturally interesting component for this system and ask the user to deep dive into it. After user answers, provide a detailed design for that component including algorithms, data structures, failure handling, and tradeoffs. Component selection guide:
- URL shortener → ID generation strategy (hash vs counter vs snowflake)
- Rate limiter → algorithm choice (token bucket, sliding window, fixed window)
- Web crawler → URL frontier and politeness
- Notification system → fanout and delivery guarantees
- Instagram → photo storage and feed generation
- Twitter → timeline construction (fanout on write vs read)
- Chat system → message delivery and read receipts
- YouTube → video transcoding pipeline
- Proximity service → geospatial indexing (geohash, quadtree)
- Key-value store → replication and consistency
- Unique ID generator → snowflake/twitter approach
- Ticket booking → concurrency and locking
- News feed → feed ranking and fanout
- Search autocomplete → trie data structure
- Message queue → durability and offset management
- Pastebin → storage and expiration
- Consistent hashing → virtual nodes
- Metrics system → time-series storage

**Step 7 — Deep Dive 2 (Scaling/Reliability)**
Ask: "How would you handle scaling bottlenecks, failures, and data durability?" After user answers, cover: horizontal scaling, sharding strategy, replication, failover, caching layers, database read replicas, CDN, rate limiting, circuit breakers, graceful degradation.

**Step 8 — Tradeoffs & Alternatives**
Ask: "What tradeoffs did you make? What alternatives did you consider?" After user answers, discuss: alternative architectures, technology choices, consistency vs availability tradeoffs (CAP), normalization vs denormalization, sync vs async processing, monolith vs microservices.

### 4. Save the solution

Write the full problem + all model answers to `~/Programming/JimmyTranDev/notes/system-design/<topic>/<YYYY-MM-DD>.md` with YAML frontmatter:

```yaml
---
topic: <topic>
date: <YYYY-MM-DD>
difficulty: <easy|medium|hard>
categories: [<relevant categories>]
---
```

The saved file should include every step: problem statement, requirements, estimates, data model, high-level design, API design, both deep dives, and tradeoffs — all with the model answers, not the user's responses. Structure clearly with markdown headings.

At the end of CLI output, print: `Full solution saved to ~/Programming/JimmyTranDev/notes/system-design/<topic>/<YYYY-MM-DD>.md`

### 5. Offer next steps

- "Would you like to try another problem?" → restart from step 1
- "Would you like to quiz yourself on this solution?" → run `/quiz` on the saved file
- "Done" → exit

## Rules

- Make problems realistic — use real-world scale numbers (e.g., 500M DAU for Twitter, 1B+ for YouTube)
- Model answers should be thorough — this is a learning tool, not a quick summary
- Do not fabricate numbers for the specific system if they're publicly known
- When the user skips a step, still show the model answer — they're here to learn
- If the saved file already exists for the same date, overwrite it
- After saving the solution, commit and push the notes repo: `git -C ~/Programming/JimmyTranDev/notes add -A && git -C ~/Programming/JimmyTranDev/notes commit -m "system-design(<topic>): solution <YYYY-MM-DD>" && git -C ~/Programming/JimmyTranDev/notes push`
