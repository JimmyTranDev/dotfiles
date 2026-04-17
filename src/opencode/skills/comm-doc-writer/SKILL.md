---
name: comm-doc-writer
description: Documentation writing patterns covering README structure, API docs, architecture decision records, changelog conventions, audience analysis, and completeness checklists
---

## Documentation Types

| Type | Purpose | Audience | Update Frequency |
|------|---------|----------|-----------------|
| README | Project overview, quick start, contribution guide | New users, contributors | Every major feature change |
| API docs | Endpoint/function reference with parameters, returns, examples | Consumers of the API | Every API change |
| Architecture Decision Record (ADR) | Why a technical decision was made, alternatives considered, consequences | Future maintainers | Once per decision, never edited |
| Changelog | User-facing summary of changes per version | Users upgrading versions | Every release |
| Inline code docs | Complex algorithm explanations, non-obvious behavior | Developers reading the code | When the code changes |
| Onboarding guide | Step-by-step environment setup, tool installation, first task | New team members | Quarterly review |
| Runbook | Operational procedures for incidents, deployments, rollbacks | On-call engineers | After every incident |

## README Structure

1. **Title + one-line description** — what this project is
2. **Badges** (optional) — build status, coverage, version, license
3. **Quick start** — minimal steps to get running (3-5 commands max)
4. **Features** — bullet list of key capabilities
5. **Installation** — detailed setup with prerequisites
6. **Usage** — common use cases with code examples
7. **Configuration** — environment variables, config files, options
8. **Contributing** — how to submit changes, coding standards, PR process
9. **License** — single line with license type

## API Documentation Pattern

```
## endpoint/function name

Brief description of what it does.

### Parameters

| Name | Type | Required | Default | Description |
|------|------|----------|---------|-------------|
| id   | string | Yes    | —       | Unique identifier |

### Returns

Description of return value with type.

### Example

Request/call example followed by response/return example.

### Errors

| Code | Condition | Resolution |
|------|-----------|------------|
| 404  | Resource not found | Verify the ID exists |
```

## Architecture Decision Record (ADR) Format

```
# ADR-NNN: Title of Decision

## Status
Accepted | Superseded by ADR-XXX | Deprecated

## Context
What is the problem or situation that requires a decision?

## Decision
What is the change that we're making?

## Alternatives Considered
What other options were evaluated and why were they rejected?

## Consequences
What are the positive, negative, and neutral effects of this decision?
```

## Changelog Conventions

Follow [Keep a Changelog](https://keepachangelog.com/) format:

| Section | Content |
|---------|---------|
| Added | New features |
| Changed | Changes to existing functionality |
| Deprecated | Features that will be removed |
| Removed | Features that were removed |
| Fixed | Bug fixes |
| Security | Vulnerability fixes |

## Writing Principles

| Principle | Rule |
|-----------|------|
| **Audience-first** | Write for the reader's knowledge level, not yours |
| **Concrete over abstract** | Show code examples, not just descriptions |
| **Scannable** | Use headers, tables, bullet lists — no walls of text |
| **Current** | Outdated docs are worse than no docs — include update triggers |
| **Minimal** | Document what's non-obvious — don't explain what the code already says |
| **Tested** | Run every command and code example before publishing |

## What to Document vs What Not To

### Document

- Non-obvious architectural decisions (why, not what)
- Setup steps that require specific tool versions or system configuration
- Complex business rules that aren't self-evident from code
- External API contracts and integration points
- Deployment procedures and environment-specific configuration
- Breaking changes and migration paths

### Do Not Document

- Self-explanatory code (variable assignments, simple CRUD operations)
- Implementation details that change frequently
- Information already captured in type signatures or function names
- Boilerplate that IDE tooling generates

## Completeness Checklist

- [ ] Can a new user go from zero to running in under 10 minutes using only the docs?
- [ ] Are all prerequisites listed with version requirements?
- [ ] Do all code examples actually work when copied and pasted?
- [ ] Are error scenarios documented with resolution steps?
- [ ] Is the documentation structure navigable — can readers find what they need without reading everything?
- [ ] Are external links verified and not broken?
- [ ] Is the writing free of jargon that the target audience wouldn't know?

## Markdown Best Practices

- Use ATX-style headers (`#`, `##`, `###`) — not setext (underlines)
- One sentence per line in source for clean diffs
- Use fenced code blocks with language identifiers for syntax highlighting
- Prefer tables over nested bullet lists for structured data
- Use relative links for internal references, absolute for external
- Keep line length under 120 characters in source
