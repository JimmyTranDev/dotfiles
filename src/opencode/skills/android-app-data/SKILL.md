---
name: android-app-data
description: Browses and pulls files from an Android app's private data folder (/data/data/<package>/) on a local emulator or device — shared_prefs, databases, files, caches — over adb, read-only on the device. Use when you need to inspect what an app stored locally, read its SharedPreferences/SQLite/JSON files, list or pull its data directory, or debug on-device persistence. Triggers on "access the app data folder", "read android app's files/shared prefs", "pull data from the emulator", "what did the app save on device", "inspect /data/data". Needs adb (Android SDK platform-tools) and a running emulator/device; private app data requires a debuggable app (run-as) or a rootable image.
---

# Android App Data Access

## Overview

An Android app's private storage lives at `/data/data/<package>/` (subdirs:
`shared_prefs/`, `databases/`, `files/`, `cache/`, `no_backup/`, …) and is not
readable by normal `adb pull`. This skill reads and pulls that data from a
**local emulator or device** via two mechanisms, chosen automatically:

1. **`run-as <package>`** — works for **debuggable** apps on any image,
   including Google Play / production emulators.
2. **`adb root` + direct path** — fallback for **rootable** images
   (userdebug/AOSP `-eng` emulators).

Non-debuggable apps on production images are inaccessible by design. All
operations are **read-only on the device** (no writes, no remounts).

## When to Use

- Inspect what an app persisted: SharedPreferences XML, SQLite DBs, JSON/files.
- List or pull an app's data directory tree to your machine for analysis.
- Debug on-device persistence (auth tokens, caches, migration state).

**Do NOT use when:**

- You only need a **SQLite verification report** (integrity, row counts,
  journal mode) — use `etc/scripts/src/ai/android-db-inspect.sh` instead, which
  pulls the DB + `-wal`/`-shm` and emits JSON.
- You need to access a real **production device's** non-debuggable app data —
  not possible without root; don't attempt workarounds.
- The target is iOS or a remote device farm — out of scope.

## The Workflow

Use the bundled helper at `scripts/android-app-data.sh` (paths are relative to
this skill's base directory). Sub-paths are relative to the app data root.

1. **Confirm a device and find the package:**
   ```bash
   scripts/android-app-data.sh devices
   scripts/android-app-data.sh packages [filter]   # marks each "debuggable" or "(no access)"
   ```
2. **Browse the data folder:**
   ```bash
   scripts/android-app-data.sh ls   <package> [subpath]     # e.g. ls com.x.app shared_prefs
   scripts/android-app-data.sh find <package> [subpath] [glob]   # e.g. find com.x.app . "*.xml"
   ```
3. **Read a file in place** (text — prefs, JSON):
   ```bash
   scripts/android-app-data.sh cat  <package> shared_prefs/com.x.app_preferences.xml
   ```
4. **Pull a file or whole directory** to your machine (default `/tmp/<package>`):
   ```bash
   scripts/android-app-data.sh pull <package> databases/app.db
   scripts/android-app-data.sh pull <package> shared_prefs /tmp/out
   ```
   Directories stream as a tar over `exec-out` — nothing is written to the device.
5. **For SQLite content**, pull the `.db` (and read it locally with `sqlite3`),
   or hand off to `android-db-inspect.sh` for a structured report.

If several devices are attached, pass `--serial <serial>` (or set
`$ANDROID_SERIAL`).

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I'll just `adb pull /data/data/<pkg>/...` directly." | That path is private; plain pull fails with permission denied. Use `run-as`/root via the script. |
| "`run-as` failed, so I'll `adb root` on this Play emulator." | Production/Play images refuse root (`adbd cannot run as root`). The app must be debuggable, or use an AOSP/userdebug image. |
| "I'll `chmod`/copy the file to /sdcard to grab it." | That writes to the device and can mutate state/permissions. Stream it read-only with `cat`/tar via the script. |
| "I just need DB stats, I'll reverse-engineer them here." | `android-db-inspect.sh` already pulls `-wal`/`-shm` and reports integrity/row counts. Don't reimplement it. |
| "No device check needed." | With multiple emulators, commands hit the wrong one. Run `devices` and use `--serial`. |

## Red Flags

- Running `adb root`/`adb disable-verity`/remount on a production device.
- Writing files to the device (`/sdcard`, `cp` inside the app dir) to extract data.
- Reporting "permission denied" without checking whether the app is debuggable
  (`packages` shows this) or trying the root fallback.
- Targeting an ambiguous device when several are attached.

## Verification

- [ ] `scripts/android-app-data.sh devices` lists the target emulator/device.
- [ ] `scripts/android-app-data.sh packages` marks the target package
      `debuggable` (or the image is confirmed rootable).
- [ ] `ls`/`find`/`cat` return real contents from `/data/data/<package>/`.
- [ ] `pull` produces a non-empty file (or populated directory) under the dest,
      and nothing was written to the device.
