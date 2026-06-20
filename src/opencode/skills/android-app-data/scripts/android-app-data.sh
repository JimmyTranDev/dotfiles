#!/usr/bin/env bash
#
# android-app-data.sh — browse and pull an Android app's private data folder
# (/data/data/<package>/) from a LOCAL emulator or device, read-only on the device.
#
# Access strategy (per command, automatic):
#   1. run-as <package>   — works for DEBUGGABLE apps on any image (incl. Play).
#   2. adb root + direct   — fallback for rootable (userdebug/AOSP) images.
# Non-debuggable apps on production/Play images are not accessible (by design).
#
# Usage:
#   android-app-data.sh devices                         List attached devices/emulators
#   android-app-data.sh packages [filter]               List debuggable 3rd-party packages
#   android-app-data.sh ls   <package> [subpath]        List a dir in the data folder (default: root)
#   android-app-data.sh cat  <package> <filepath>       Print a file's contents
#   android-app-data.sh find <package> [subpath] [glob] List files (optional name glob)
#   android-app-data.sh pull <package> <src> [destdir]  Pull a file or directory tree (default destdir: /tmp/<package>)
#
# Options:
#   --serial <serial>   Target a specific device when several are attached (else $ANDROID_SERIAL, else the only one)
#
# Notes:
#   - <subpath>/<src> are relative to the app data root (/data/data/<package>/),
#     e.g. "databases/app.db", "shared_prefs", "files/cache.json".
#   - For SQLite verification specifically, prefer etc/scripts/src/ai/android-db-inspect.sh.

set -euo pipefail

SERIAL="${ANDROID_SERIAL:-}"

ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --serial) SERIAL="${2:-}"; shift 2 ;;
    --serial=*) SERIAL="${1#--serial=}"; shift ;;
    *) ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-}"

err() { printf '%s\n' "$*" >&2; }
die() { err "$*"; exit 1; }

command -v adb >/dev/null 2>&1 || die "adb not found (install Android SDK platform-tools)."

# Resolve a single target serial.
resolve_serial() {
  if [ -n "$SERIAL" ]; then printf '%s\n' "$SERIAL"; return 0; fi
  local devs
  devs="$(adb devices | awk 'NR>1 && $2=="device" {print $1}')"
  local n
  n="$(printf '%s\n' "$devs" | grep -c . || true)"
  if [ "$n" -eq 0 ]; then die "No attached device in 'device' state. Start an emulator first."; fi
  if [ "$n" -gt 1 ]; then
    err "Multiple devices attached; pass --serial <serial>:"; printf '%s\n' "$devs" >&2; exit 2
  fi
  printf '%s\n' "$devs"
}

A() { adb -s "$SERIAL" "$@"; }

# Is the package reachable via run-as?
can_run_as() {
  A shell run-as "$1" true </dev/null >/dev/null 2>&1
}

# Echo "run-as" or "root" (the usable access method) or fail.
access_method() {
  local pkg="$1"
  if can_run_as "$pkg"; then printf 'run-as\n'; return 0; fi
  A root >/dev/null 2>&1 || true
  if A shell "ls /data/data/$pkg >/dev/null 2>&1" >/dev/null 2>&1; then printf 'root\n'; return 0; fi
  return 1
}

cmd_devices() {
  adb devices -l
}

cmd_packages() {
  SERIAL="$(resolve_serial)"
  local filter="${1:-}"
  local pkgs
  pkgs="$(A shell pm list packages -3 2>/dev/null | sed 's/package://' | tr -d '\r' | sort)"
  [ -n "$filter" ] && pkgs="$(printf '%s\n' "$pkgs" | grep -i -- "$filter" || true)"
  if [ -z "$pkgs" ]; then err "No matching third-party packages."; return 0; fi
  printf '%s\n' "$pkgs" | while IFS= read -r p; do
    [ -z "$p" ] && continue
    if can_run_as "$p"; then printf 'debuggable  %s\n' "$p"; else printf '(no access) %s\n' "$p"; fi
  done
}

cmd_ls() {
  SERIAL="$(resolve_serial)"
  local pkg="${1:?Usage: ls <package> [subpath]}" sub="${2:-}"
  local m; m="$(access_method "$pkg")" || die "Cannot access $pkg (not debuggable and device not rootable)."
  if [ "$m" = "run-as" ]; then
    A shell run-as "$pkg" ls -la "$sub" 2>&1
  else
    A shell ls -la "/data/data/$pkg/$sub" 2>&1
  fi
}

cmd_cat() {
  SERIAL="$(resolve_serial)"
  local pkg="${1:?Usage: cat <package> <filepath>}" path="${2:?Usage: cat <package> <filepath>}"
  local m; m="$(access_method "$pkg")" || die "Cannot access $pkg."
  if [ "$m" = "run-as" ]; then
    A exec-out run-as "$pkg" cat "$path"
  else
    A exec-out cat "/data/data/$pkg/$path"
  fi
}

cmd_find() {
  SERIAL="$(resolve_serial)"
  local pkg="${1:?Usage: find <package> [subpath] [glob]}" sub="${2:-.}" glob="${3:-}"
  local m; m="$(access_method "$pkg")" || die "Cannot access $pkg."
  local args=( "$sub" -type f )
  [ -n "$glob" ] && args+=( -name "$glob" )
  if [ "$m" = "run-as" ]; then
    A shell run-as "$pkg" find "${args[@]}" 2>&1
  else
    A shell find "/data/data/$pkg/$sub" -type f ${glob:+-name "$glob"} 2>&1
  fi
}

cmd_pull() {
  SERIAL="$(resolve_serial)"
  local pkg="${1:?Usage: pull <package> <src> [destdir]}" src="${2:?Usage: pull <package> <src> [destdir]}"
  local destdir="${3:-/tmp/$pkg}"
  mkdir -p "$destdir"
  local m; m="$(access_method "$pkg")" || die "Cannot access $pkg."

  # Determine if src is a directory.
  local is_dir="false"
  if [ "$m" = "run-as" ]; then
    A shell run-as "$pkg" test -d "$src" >/dev/null 2>&1 && is_dir="true"
  else
    A shell test -d "/data/data/$pkg/$src" >/dev/null 2>&1 && is_dir="true"
  fi

  if [ "$is_dir" = "true" ]; then
    # Stream a tar of the directory and unpack locally — no device-side temp files.
    local base name
    base="$(dirname "$src")"; name="$(basename "$src")"
    [ "$base" = "." ] && base="."
    if [ "$m" = "run-as" ]; then
      A exec-out run-as "$pkg" tar -c -C "$base" "$name" 2>/dev/null | tar -x -C "$destdir"
    else
      A exec-out tar -c -C "/data/data/$pkg/$base" "$name" 2>/dev/null | tar -x -C "$destdir"
    fi
    err "Pulled directory '$src' -> $destdir/$name"
  else
    local out="$destdir/$(basename "$src")"
    if [ "$m" = "run-as" ]; then
      A exec-out run-as "$pkg" cat "$src" > "$out"
    else
      A exec-out cat "/data/data/$pkg/$src" > "$out"
    fi
    [ -s "$out" ] || { rm -f "$out"; die "Pulled file is empty or missing: $src"; }
    err "Pulled file '$src' -> $out"
    printf '%s\n' "$out"
  fi
}

main() {
  local sub="${1:-}"
  [ $# -gt 0 ] && shift || true
  case "$sub" in
    devices) cmd_devices ;;
    packages|pkgs) cmd_packages "$@" ;;
    ls)   cmd_ls "$@" ;;
    cat)  cmd_cat "$@" ;;
    find) cmd_find "$@" ;;
    pull) cmd_pull "$@" ;;
    ""|-h|--help|help)
      sed -n '3,33p' "$0" | sed 's/^# \{0,1\}//'
      ;;
    *) die "Unknown command: $sub (try: devices | packages | ls | cat | find | pull)" ;;
  esac
}

main "$@"
