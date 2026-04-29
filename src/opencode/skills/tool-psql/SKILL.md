---
name: tool-psql
description: PostgreSQL psql CLI patterns covering connection strings, schema inspection, common queries, data export, transactions, and Cloud SQL Proxy workflows
---

PostgreSQL CLI reference for AI agents interacting with databases via `psql`.

## Connection

| Method | Command |
|--------|---------|
| Local | `psql -U <user> -d <database>` |
| Remote | `psql -h <host> -p <port> -U <user> -d <database>` |
| Connection string | `psql "postgresql://<user>:<pass>@<host>:<port>/<database>"` |
| Cloud SQL Proxy | Start proxy: `cloud-sql-proxy <instance>` then `psql -h 127.0.0.1 -p 5432 -U <user> -d <database>` |
| With SSL | `psql "postgresql://<user>:<pass>@<host>/<db>?sslmode=require"` |

## Schema Inspection

| Command | Purpose |
|---------|---------|
| `\dt` | List tables |
| `\dt+` | List tables with size |
| `\d <table>` | Describe table (columns, types, constraints) |
| `\di` | List indexes |
| `\di <table>` | List indexes for specific table |
| `\df` | List functions |
| `\dv` | List views |
| `\dn` | List schemas |
| `\l` | List databases |
| `\du` | List roles |
| `\x` | Toggle expanded display |

## Common Queries

### Row counts
```sql
SELECT schemaname, relname, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC;
```

### Table sizes
```sql
SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname || '.' || tablename))
FROM pg_tables WHERE schemaname = 'public' ORDER BY pg_total_relation_size(schemaname || '.' || tablename) DESC;
```

### Active connections
```sql
SELECT pid, usename, application_name, state, query_start, query FROM pg_stat_activity WHERE state != 'idle';
```

### Blocking queries
```sql
SELECT blocked.pid AS blocked_pid, blocking.pid AS blocking_pid, blocked.query AS blocked_query
FROM pg_locks blocked_locks
JOIN pg_stat_activity blocked ON blocked.pid = blocked_locks.pid
JOIN pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
  AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
  AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
  AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
  AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
  AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
  AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
  AND blocking_locks.pid != blocked_locks.pid
JOIN pg_stat_activity blocking ON blocking.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;
```

### Index usage
```sql
SELECT relname, indexrelname, idx_scan, idx_tup_read, idx_tup_fetch
FROM pg_stat_user_indexes ORDER BY idx_scan ASC;
```

### Missing indexes (sequential scans on large tables)
```sql
SELECT relname, seq_scan, seq_tup_read, idx_scan
FROM pg_stat_user_tables WHERE seq_scan > 100 AND idx_scan < 10 ORDER BY seq_tup_read DESC;
```

## Data Export

| Format | Command |
|--------|---------|
| CSV | `\copy (SELECT * FROM table) TO 'file.csv' WITH CSV HEADER` |
| TSV | `\copy (SELECT * FROM table) TO 'file.tsv' WITH DELIMITER E'\t' HEADER` |
| JSON | `psql -c "SELECT json_agg(t) FROM table t" -t -o file.json` |
| SQL dump | `pg_dump -U <user> -d <db> -t <table> --data-only > dump.sql` |
| Schema only | `pg_dump -U <user> -d <db> --schema-only > schema.sql` |

## Transaction Handling

```sql
BEGIN;
-- make changes
-- verify with SELECT
COMMIT;
-- or ROLLBACK; if something is wrong
```

| Command | Purpose |
|---------|---------|
| `BEGIN;` | Start transaction |
| `SAVEPOINT sp1;` | Create savepoint |
| `ROLLBACK TO sp1;` | Rollback to savepoint |
| `COMMIT;` | Commit transaction |
| `ROLLBACK;` | Rollback entire transaction |

## Non-Interactive Execution

| Pattern | Command |
|---------|---------|
| Single query | `psql -c "SELECT count(*) FROM users"` |
| File | `psql -f script.sql` |
| Quiet output | `psql -t -A -c "SELECT count(*) FROM users"` |
| With variables | `psql -v table_name='users' -c "SELECT * FROM :table_name"` |

## Cloud SQL Proxy Workflow

1. Start proxy: `cloud-sql-proxy <project>:<region>:<instance> --port=5432`
2. Connect: `psql -h 127.0.0.1 -p 5432 -U <user> -d <database>`
3. If port conflict, use different port: `--port=5433` and `psql -p 5433`

## Compare Schemas

```bash
pg_dump --schema-only -d db1 > schema1.sql
pg_dump --schema-only -d db2 > schema2.sql
diff schema1.sql schema2.sql
```
