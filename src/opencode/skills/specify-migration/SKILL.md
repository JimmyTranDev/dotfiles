---
name: specify-migration
description: Specify skill for database migration planning — defines analysis categories, skills to load, agents to launch, and severity classification
---

## Spec Filename Prefix

`migration-`

## Skills to Load

- **tool-drizzle-orm**: Drizzle ORM patterns (if Drizzle detected)

### ORM Detection

- Drizzle: load **tool-drizzle-orm**
- Prisma: look for prisma/schema.prisma
- TypeORM: look for ormconfig or DataSource config
- Raw SQL: look for migrations/ directory with .sql files
- If no database tooling detected, notify and stop

## Agents to Launch

None specified.

## Analysis Categories

### Current Schema Analysis

- Tables/models and their relationships
- Existing indexes
- Current migration history

### Spec Output Sections

- Current schema state (relevant tables only)
- Proposed schema changes with rationale
- Migration steps in order (with SQL or ORM code)
- Rollback strategy for each step
- Data backfill requirements (if any)
- Index changes and performance implications
- Breaking changes that affect application code
- Zero-downtime deployment considerations
- Testing strategy (test data, edge cases)

### Constraints

- Always include rollback strategy for every migration step
- Flag destructive operations (DROP TABLE, DROP COLUMN) prominently
- Note if migrations require maintenance windows vs. can run online

## Severity Classification

- **Critical**: Destructive operations, data loss risk
- **High**: Breaking changes to application code
- **Medium**: Performance implications, missing indexes
- **Low**: Schema improvements, naming conventions

## Scope Overrides

None — uses default scope detection.
