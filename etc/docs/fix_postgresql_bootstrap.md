# Fix PostgreSQL Bootstrap Failed: 5

The `Bootstrap failed: 5` error from `brew services` usually indicates a permissions conflict, a stale process, or a dirty state in `launchctl` where the system thinks the service is already partially loaded.

## 1. Clean Slate

Stop and restart through Homebrew to clear stale handles.

```sh
brew services stop postgresql@15
brew services start postgresql@15
```

## 2. Manual Unload/Load

If the Homebrew wrapper fails, go directly to `launchctl`.

```sh
launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql@15.plist
launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql@15.plist
```

## 3. Remove Stale PID File

A leftover `postmaster.pid` from a crash tells Postgres it is already running.

Data directory is `/opt/homebrew/var/postgresql@15` (Apple Silicon) or `/usr/local/var/postgresql@15` (Intel).

```sh
rm /opt/homebrew/var/postgresql@15/postmaster.pid
brew services start postgresql@15
```

## 4. Fix Ownership

An `Input/output error` can mask a permissions problem if Homebrew files were touched by `sudo`.

```sh
sudo chown -R $(whoami) $(brew --prefix)/*
```

Avoid using `sudo` with `brew services` — it creates root-owned files in your user directory.

## Verify

```sh
brew services list
```

Status should show `started` (green). If it still fails, check the logs:

```sh
tail -n 50 /opt/homebrew/var/log/postgresql@15.log
```
