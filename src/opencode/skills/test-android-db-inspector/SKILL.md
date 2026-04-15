---
name: test-android-db-inspector
description: Pull and inspect SQLite databases from Android emulators using adb and sqlite3, including table inspection, queries, and data verification
---

Pull SQLite databases from Android emulators, inspect schemas, query data, and verify database state.

## Prerequisites

| Tool | Install | Verify |
|------|---------|--------|
| `adb` | Included with Android SDK (`$ANDROID_HOME/platform-tools/adb`) | `adb version` |
| `sqlite3` | `brew install sqlite` | `sqlite3 --version` |
| Emulator running | `emulator -list-avds` then `emulator -avd <name>` | `adb devices` |

## Locate the Database

### Debug Builds (run-as)

```bash
adb shell run-as <package.name> ls databases/
```

### Pull via run-as (no root required for debug builds)

```bash
adb shell run-as <package.name> cat databases/<db-name> > /tmp/<db-name>
adb shell run-as <package.name> cat databases/<db-name>-wal > /tmp/<db-name>-wal
adb shell run-as <package.name> cat databases/<db-name>-shm > /tmp/<db-name>-shm
```

### Pull via adb root (emulator only)

```bash
adb root
adb pull /data/data/<package.name>/databases/<db-name> /tmp/<db-name>
adb pull /data/data/<package.name>/databases/<db-name>-wal /tmp/<db-name>-wal
adb pull /data/data/<package.name>/databases/<db-name>-shm /tmp/<db-name>-shm
```

Always pull WAL and SHM files alongside the main database to avoid missing uncommitted writes.

## Find the Package Name

```bash
adb shell pm list packages | grep <keyword>
adb shell pm list packages -3
```

The `-3` flag lists only third-party (non-system) packages.

## Inspect the Database

### Open with sqlite3

```bash
sqlite3 /tmp/<db-name>
```

### Common Queries

| Task | Command |
|------|---------|
| List all tables | `.tables` |
| Show schema for all tables | `.schema` |
| Show schema for one table | `.schema <table>` |
| Show column names with types | `PRAGMA table_info(<table>);` |
| Count rows | `SELECT COUNT(*) FROM <table>;` |
| Sample data | `SELECT * FROM <table> LIMIT 10;` |
| Show database version | `PRAGMA user_version;` |
| List all indexes | `.indexes` |
| Show index details | `PRAGMA index_info(<index>);` |
| Check foreign keys | `PRAGMA foreign_key_list(<table>);` |
| Verify foreign key integrity | `PRAGMA foreign_key_check;` |
| Check database integrity | `PRAGMA integrity_check;` |
| Show database file size | `SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size();` |

### Output Formatting

```bash
sqlite3 /tmp/<db-name> -header -column "SELECT * FROM <table> LIMIT 10;"
```

| Flag | Effect |
|------|--------|
| `-header` | Show column names |
| `-column` | Align output in columns |
| `-json` | Output as JSON array |
| `-csv` | Output as CSV |
| `-line` | One value per line |

### Export Data

```bash
sqlite3 /tmp/<db-name> -header -csv "SELECT * FROM <table>;" > /tmp/<table>.csv
sqlite3 /tmp/<db-name> -json "SELECT * FROM <table>;" > /tmp/<table>.json
sqlite3 /tmp/<db-name> .dump > /tmp/<db-name>.sql
```

## Verification Checklist

- [ ] Database file pulled successfully (non-zero size)
- [ ] WAL file included (or WAL mode not in use: `PRAGMA journal_mode;`)
- [ ] `PRAGMA integrity_check;` returns `ok`
- [ ] Expected tables exist (`.tables`)
- [ ] Table schemas match expected column names and types (`PRAGMA table_info`)
- [ ] Row counts are reasonable (`SELECT COUNT(*)`)
- [ ] Foreign key constraints pass (`PRAGMA foreign_key_check;`)
- [ ] No orphaned rows (join parent tables to verify references)
- [ ] Timestamps are in expected format and timezone
- [ ] No unexpected NULL values in required columns

## Multiple Emulators

```bash
adb devices
adb -s <serial> shell run-as <package.name> cat databases/<db-name> > /tmp/<db-name>
```

Use `-s <serial>` to target a specific device when multiple emulators are running.

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| `run-as: unknown package` | Package not installed | Verify with `adb shell pm list packages` |
| `run-as: is not debuggable` | Release build | Use `adb root` on emulator, or use a debug build |
| `remote object does not exist` | Wrong database path | List files first: `adb shell run-as <pkg> ls databases/` |
| Database appears empty | WAL not pulled | Pull the `-wal` and `-shm` files too |
| `database is locked` | App is actively writing | Stop the app: `adb shell am force-stop <pkg>` |
| `adb root` fails | Production emulator image | Use a Google APIs image (not Google Play) |
