---
name: migration-check
description: Check for pending Flyway database migrations in the current project
---

Usage: /migration-check

Check for new or pending Flyway database migrations in the current Java Spring project.

1. Verify this is a Java project:
   - Check for `pom.xml`, `build.gradle`, or `build.gradle.kts`
   - If none found, report "Not a Java project" and exit

2. Find migration files:
   - Search for Flyway migration directory: `src/main/resources/db/migration/`
   - If not found, check common alternatives: `src/main/resources/migration/`, `db/migration/`
   - If no migration directory exists, report and exit

3. Analyze migrations:
   - List all migration files sorted by version number
   - Compare against the current branch's diff: `git diff develop...HEAD -- '**/db/migration/**'`
   - Identify which migrations are new (added in this branch)
   - Check migration naming convention: `V<version>__<description>.sql`

4. Validate new migrations:
   - Check for naming conflicts with existing migrations
   - Verify version numbers are sequential and don't gap unexpectedly
   - Read migration SQL and check for common issues:
     - Missing `IF NOT EXISTS` / `IF EXISTS` for safety
     - Destructive operations without backups (DROP TABLE, DROP COLUMN)
     - Missing indexes on foreign keys
     - Large data migrations that should be batched

5. Report:
   - Total migration count
   - New migrations in this branch (with filenames and brief description)
   - Any validation warnings
   - Suggest running `flyway info` if the tool is available
