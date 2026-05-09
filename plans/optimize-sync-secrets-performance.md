# Optimize sync_secrets.sh Performance

## TL;DR

- Script uploads/downloads files sequentially via `bw` CLI — each call takes 1-3s network round-trip
- 5 optimizations identified: reduce redundant `bw get item` calls, parallel uploads/downloads, tar-based single-attachment strategy, skip unchanged files, parallel deletion
- Most critical: switch from N attachments to 1 tarball attachment (eliminates N sequential API calls)
- Estimated effort: medium (single file, ~290 lines)
- Expected speedup: from O(N) API calls to O(1) for upload/download

## Overview

`sync_secrets.sh` syncs a local secrets directory to/from a Bitwarden Secure Note via attachments. The current approach uploads each file as a separate attachment sequentially, making performance linear with file count. Each `bw` CLI call involves a network round-trip (1-3s), so syncing 10 files takes 20-60s.

## Architecture

Single script at `etc/scripts/src/sync_secrets.sh`. Sources `utils/logging.sh`. Interacts with `bw` CLI (Bitwarden) and stores files at `~/Programming/JimmyTranDev/secrets/`. No other scripts depend on the internal attachment structure — only the upload/download contract matters.

## Data flow

**Current (slow):**
1. Find all files in secrets dir
2. For each file: `bw create attachment` (sequential, 1-3s each)
3. Upload manifest
4. Delete old attachments (sequential, 1-3s each)

**Proposed (fast):**
1. Find all files in secrets dir
2. Create single tarball of all files
3. `bw create attachment` once (single API call)
4. Delete old attachment (single API call)

## Tasks

### Task 1: Cache `bw get item` result
- **File**: `etc/scripts/src/sync_secrets.sh`
- **Change**: Call `bw get item` once at the start of upload/download, store full JSON in a variable, extract item_id and attachment info from the cached result instead of calling `bw get item` 3 separate times (lines 49, 93, 96 in upload; lines 186, 194 in download)
- **Complexity**: small
- **Parallel**: yes (independent of other tasks)

### Task 2: Replace N-attachment strategy with single tarball
- **File**: `etc/scripts/src/sync_secrets.sh`
- **Change**: In `upload_secrets`, replace the per-file attachment loop with: `tar czf` all secrets into one `.tar.gz`, upload single attachment. In `download_secrets`, download single attachment, `tar xzf` to restore. This eliminates the manifest file and the `__SLASH__` encoding.
- **Dependencies**: None
- **Complexity**: medium
- **Parallel**: no (this is the core change, tasks 3-5 become unnecessary if this is adopted)

### Task 3: Skip unchanged files (incremental sync) — OPTIONAL
- **File**: `etc/scripts/src/sync_secrets.sh`
- **Change**: Before uploading, compute a checksum (sha256) of the tarball. Store the checksum as the Secure Note's `notes` field. On next upload, compare checksums and skip if identical. Saves the entire upload when nothing changed.
- **Dependencies**: Task 2
- **Complexity**: small
- **Parallel**: no (depends on Task 2)

### Task 4: Parallel old attachment deletion — OPTIONAL if Task 2 adopted
- **File**: `etc/scripts/src/sync_secrets.sh`
- **Change**: If keeping multi-attachment approach, use `xargs -P4` or background jobs (`&` + `wait`) to delete old attachments in parallel instead of sequentially.
- **Dependencies**: Only needed if Task 2 is rejected
- **Complexity**: small
- **Parallel**: yes

### Task 5: Reduce `bw sync` calls
- **File**: `etc/scripts/src/sync_secrets.sh`
- **Change**: `bw sync` is called in `ensure_bw_unlocked` (potentially twice on the locked->unlocked path: lines 21 and 43). Ensure only one sync call happens per script invocation.
- **Complexity**: small
- **Parallel**: yes (independent)

## API contracts

No external API changes. The Bitwarden item structure changes from N attachments + manifest to 1 tarball attachment. This is an internal detail — the upload/download CLI interface (`sync_secrets.sh upload|download`) stays the same.

**Migration**: First run after the change should handle both old format (multiple attachments + manifest) and new format (single tarball) during download, to allow a smooth transition.

## State changes

- Bitwarden item attachment structure changes from N files + `.manifest` to 1 `.tar.gz`
- Optional: item `notes` field used to store content checksum for incremental sync

## Edge cases

- **Migration**: Download must detect whether attachments are old format (multiple + manifest) or new format (single tarball) and handle both
- **Empty secrets dir**: tar with no files — handle gracefully
- **Large secrets**: Single tarball could hit Bitwarden attachment size limits (100MB for premium). Current per-file approach has same total limit, so no regression
- **Tarball corruption**: Download should verify tar extraction succeeded before removing backup

## Testing approach

- Manual testing: time `upload` and `download` with 5-10 test files before/after changes
- Verify round-trip: upload then download produces identical files (`diff -r`)
- Verify migration: create attachments in old format, run new download, confirm files restore correctly
- Verify checksum skip: upload twice with no changes, second run should skip

## Open questions

### Architecture

1. **Single tarball vs keeping multi-attachment?** Decision: Single tarball. User only accesses secrets via the script.

### Scope

2. **Incremental sync (Task 3)?** Decision: Yes, add checksum-based skip.

### Risks

3. **Old format migration**: Decision: No migration needed. User will manually re-upload before using the new script. Task 4 (parallel deletion) is cancelled.
