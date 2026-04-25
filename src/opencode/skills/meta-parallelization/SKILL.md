---
name: meta-parallelization
description: Patterns for maximizing parallel execution of tool calls, skill loading, agent delegation, codebase exploration, and git operations
---

Maximize parallel execution at every level to reduce latency and total task time. Never serialize operations that could run concurrently.

## Core Principle

If operation B does not depend on operation A's output, run them together in a single message.

## Tool Calls

| Pattern | Parallel? | Example |
|---------|-----------|---------|
| Reading multiple files | Yes | Read `config.ts`, `types.ts`, `utils.ts` in one message |
| Running independent searches | Yes | Grep for `handleError` and glob for `*.test.ts` together |
| Reading then editing the same file | No | Must read first to get content, then edit |
| Multiple independent edits | Yes | Edit `fileA.ts` and `fileB.ts` in one message |
| Launching independent agents | Yes | Run **reviewer** and **auditor** together |

### Common Parallel Batches

- **Start of task**: read relevant files + run `git status` + run `git log` + load skills
- **After implementation**: launch **reviewer** + **auditor** + **tester** together
- **Multiple fixes**: launch **fixer** agents for independent files together
- **Information gathering**: glob + grep + file reads in one batch

## Skill Loading

- Load all needed skills in a single parallel batch at the start of a task
- Skills are read-only reference material with no side effects — always safe to load in parallel
- Never load skills one at a time sequentially

| Do | Don't |
|----|-------|
| Load **code-follower**, **code-conventions**, **ts-total-typescript** in one message | Load **code-follower**, wait, then load **code-conventions**, wait, then load **ts-total-typescript** |

## Agent Delegation

| Scenario | Parallel? | Reason |
|----------|-----------|--------|
| **reviewer** + **auditor** on completed code | Yes | Independent analysis |
| **tester** + **optimizer** when both needed | Yes | Independent tasks |
| **fixer** for bugs in different files | Yes | No shared state |
| **fixer** after **reviewer** findings | No | Fixer depends on reviewer output |
| **reviewer** after **fixer** applies fixes | No | Verification depends on fixes |

### Agent Parallelism Rules

1. Launch independent agents in a single message
2. Only serialize when one agent's output feeds into another
3. When fixing issues across multiple files, launch separate **fixer** agents per file in parallel
4. After parallel agents complete, merge their findings before proceeding

## Codebase Exploration

- Batch related file reads and searches into parallel calls
- Use the **explore** agent for open-ended searches to avoid sequential tool call chains
- Never read files one at a time when multiple are needed

| Do | Don't |
|----|-------|
| Read `src/auth/login.ts`, `src/auth/types.ts`, `src/auth/utils.ts` in one message | Read `login.ts`, wait, read `types.ts`, wait, read `utils.ts` |
| Launch **explore** agent for "find all error handling patterns" | Grep → read → grep → read in a chain |

## Git Operations

| Operation Type | Parallel? | Examples |
|---------------|-----------|---------|
| Read-only info commands | Yes | `git status`, `git diff`, `git log` together |
| Independent branch operations | Yes | Push multiple branches |
| Sequential mutations | No | `git add` before `git commit`, `git commit` before `git push` |

### Common Git Parallel Batches

- **Pre-commit check**: `git status` + `git diff` + `git diff --cached` + `git log --oneline -5`
- **PR context gathering**: `gh pr view` + `git diff base...HEAD` + `git log base..HEAD`
- **Multi-worktree**: push all branches in parallel, create all PRs in parallel

## Batch File Processing (Fan-Out Pattern)

When processing many files (e.g., vocabulary batches, migrations, data files), divide the workload across multiple parallel agents:

1. **Count total files** and decide agent count + files-per-agent (e.g., 338 files ÷ 10 agents = ~34 each)
2. **Launch all agents in a single message** — each receives its file range, the task instructions, and any loaded skill content
3. **Each agent independently** reads its files, performs the work, writes back changes, and returns a per-file summary
4. **Collect results** from all agents and merge into a combined report

| Step | Parallel? | Example |
|------|-----------|---------|
| Load skills + list directory | Yes | Load 3 skills + `ls` in one message |
| Launch N agents for N file ranges | Yes | 10 agents each handling 34 files |
| Merge agent results into report | No | Depends on all agents completing |

### Sizing Guidelines

| Total Files | Agents | Files/Agent |
|-------------|--------|-------------|
| < 10 | 1–2 | All |
| 10–50 | 3–5 | ~10 |
| 50–200 | 5–8 | ~25 |
| 200+ | 8–10 | ~30–35 |

### Key Rules

- Pass full skill/instruction content to each agent — do not summarize or paraphrase
- Each agent's work must be independent (no shared state between agents)
- Assign contiguous file ranges (e.g., batch_001–034) for simplicity
- Include file count in each agent's prompt so it knows when it's done

## Anti-Patterns

| Anti-Pattern | Fix |
|-------------|-----|
| Reading files one at a time | Batch all needed reads in one message |
| Loading skills sequentially | Load all skills in one parallel batch |
| Running **reviewer** then **auditor** separately | Launch both in one message |
| Running `git status` then `git diff` then `git log` | Run all three in one message |
| Waiting for grep results before reading a known file | Read the file and grep in parallel |
| Sequential agent launches for independent tasks | Launch all independent agents together |

## Decision Flowchart

```
For each pair of operations A and B:
  Does B need A's output? → No  → Run in parallel
                          → Yes → Run sequentially
```

When in doubt, ask: "Can I start B without knowing A's result?" If yes, parallelize.
