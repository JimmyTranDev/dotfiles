---
name: specify-migration
description: Generate implementation specs for database migration planning in plans/
---

Usage: /specify-migration [scope or description]

Analyze the current database schema and generate an implementation spec for planned migration changes.

$ARGUMENTS

1. Detect the ORM/migration tool in use:
   - Drizzle: load the **tool-drizzle-orm** skill
   - Prisma: look for prisma/schema.prisma
   - TypeORM: look for ormconfig or DataSource config
   - Raw SQL: look for migrations/ directory with .sql files
2. If no database tooling is detected, notify the user and stop
3. Analyze the current schema:
   - Tables/models and their relationships
   - Existing indexes
   - Current migration history
4. Based on the scope/description, determine what migration changes are needed
5. Generate an implementation spec covering:
   - Current schema state (relevant tables only)
   - Proposed schema changes with rationale
   - Migration steps in order (with SQL or ORM code)
   - Rollback strategy for each step
   - Data backfill requirements (if any)
   - Index changes and their performance implications
   - Breaking changes that affect application code
   - Zero-downtime deployment considerations
   - Testing strategy (test data, edge cases)
6. Write the spec to `plans/migration-<descriptive-name>.md`
7. If the `plans/` directory does not exist, create it
8. Print a summary to chat: spec file path, tables affected, breaking changes count, and risk level

Constraints:
- Do not apply any changes — this is spec generation only
- Always include rollback strategy for every migration step
- Flag any destructive operations (DROP TABLE, DROP COLUMN) prominently
- Note if migrations require maintenance windows vs. can run online
