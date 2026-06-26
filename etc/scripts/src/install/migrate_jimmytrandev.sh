#!/usr/bin/env bash
#
# migrate-jimmytrandev.sh
#
# One-time migration: rename ~/Programming/JimmyTranDev -> ~/Programming/jimmytrandev
# and fix everything that hardcodes the old path.
#
# What it does (in order):
#   1. Pre-flight safety checks (old exists, new absent, clean-ish git state).
#   2. Rename the folder (via a temp name so it also works on case-INsensitive
#      filesystems where JimmyTranDev and jimmytrandev collide).
#   3. Rewrite the substring "Programming/JimmyTranDev" -> "Programming/jimmytrandev"
#      in every text file under the folder. This covers all variants:
#        ~/Programming/JimmyTranDev   $HOME/Programming/JimmyTranDev
#        /Users/<you>/Programming/JimmyTranDev   ../Programming/JimmyTranDev
#      and deliberately does NOT touch the GitHub handle "github.com/JimmyTranDev".
#   4. Re-point any symlinks whose target contains the old absolute path.
#   5. Re-run the dotfiles link installer so all $HOME symlinks point at the new path.
#
# Default mode is DRY-RUN. Re-run with --apply to make changes.
#
# Usage:
#   ./migrate-jimmytrandev.sh            # dry run, shows everything it would do
#   ./migrate-jimmytrandev.sh --apply    # perform the migration
#   ./migrate-jimmytrandev.sh --apply --skip-links   # skip the $HOME re-link step

set -euo pipefail

# ---- configuration ---------------------------------------------------------
PARENT="$HOME/Programming"
OLD_NAME="JimmyTranDev"
NEW_NAME="jimmytrandev"

OLD_DIR="$PARENT/$OLD_NAME"
NEW_DIR="$PARENT/$NEW_NAME"

# The exact substring we rewrite. Anchored with "Programming/" so the bare
# GitHub username "JimmyTranDev" (github.com/JimmyTranDev) is left untouched.
OLD_REF="Programming/$OLD_NAME"
NEW_REF="Programming/$NEW_NAME"

# Path to the dotfiles link installer (relative to the migrated folder).
LINK_SCRIPT_REL="dotfiles/etc/scripts/src/install/sync_links.sh"

# Directories never worth scanning/rewriting: vendored, generated, or VCS dirs.
# (Verified the old path has zero references inside node_modules, so skipping
# them is purely a speed/safety win — a 7GB tree drops to a fast scan.)
PRUNE_DIRS=(.git node_modules .venv venv dist build .next .turbo .cache target vendor .expo .cxx .gradle)

# grep --exclude-dir flags built from PRUNE_DIRS.
GREP_EXCLUDES=()
for d in "${PRUNE_DIRS[@]}"; do GREP_EXCLUDES+=(--exclude-dir="$d"); done

APPLY=false
SKIP_LINKS=false

# ---- pretty logging --------------------------------------------------------
c_blue()  { printf '\033[34m%s\033[0m\n' "$*"; }
c_green() { printf '\033[32m%s\033[0m\n' "$*"; }
c_yellow(){ printf '\033[33m%s\033[0m\n' "$*"; }
c_red()   { printf '\033[31m%s\033[0m\n' "$*"; }
step()    { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
note()    { printf '    %s\n' "$*"; }

usage() {
	cat <<EOF
Usage: $(basename "$0") [--apply] [--skip-links] [--help]

  (no flags)     Dry run: report every change without touching anything.
  --apply        Perform the migration.
  --skip-links   Do not re-run the dotfiles link installer (step 5).
  --help         Show this help.
EOF
}

# ---- portable sed in-place -------------------------------------------------
sed_inplace() {
	# sed_inplace <expr> <file>
	if sed --version >/dev/null 2>&1; then
		sed -i -e "$1" "$2"        # GNU sed
	else
		sed -i '' -e "$1" "$2"     # BSD/macOS sed
	fi
}

# Escape a string for safe use inside a sed s|...|...| expression.
sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

# ---- git-ignore awareness --------------------------------------------------
# Find the git repo a file lives in (empty if none).
repo_root() { git -C "$(dirname "$1")" rev-parse --show-toplevel 2>/dev/null; }

# True (0) if the file is git-ignored within its repo. Untracked-but-not-ignored
# files (e.g. secrets/.gitconfig) and files outside any repo are NOT ignored,
# so they are kept. This is what filters out live session logs and build caches
# (which are gitignored) while preserving real config/source files.
is_ignored() {
	local f="$1" root
	root="$(repo_root "$f")"
	[[ -z "$root" ]] && return 1
	git -C "$root" check-ignore -q "$f" 2>/dev/null
}

# ---- argument parsing ------------------------------------------------------
while [[ $# -gt 0 ]]; do
	case "$1" in
		--apply)      APPLY=true; shift ;;
		--skip-links) SKIP_LINKS=true; shift ;;
		--help|-h)    usage; exit 0 ;;
		*)            c_red "Unknown option: $1"; usage; exit 1 ;;
	esac
done

if $APPLY; then
	c_yellow "MODE: APPLY  (changes will be made)"
else
	c_blue   "MODE: DRY RUN  (no changes — re-run with --apply to execute)"
fi

# ---------------------------------------------------------------------------
# Step 1: pre-flight checks
# ---------------------------------------------------------------------------
step "1. Pre-flight checks"

if [[ ! -d "$OLD_DIR" ]]; then
	c_red "Source folder not found: $OLD_DIR"
	# Maybe it was already migrated.
	[[ -d "$NEW_DIR" ]] && note "Target already exists: $NEW_DIR (already migrated?)"
	exit 1
fi
note "Found source: $OLD_DIR"

# On a case-sensitive FS, NEW_DIR is a genuinely different name. On a
# case-insensitive FS, [ -e ] would also match the old dir, so compare inodes.
if [[ -e "$NEW_DIR" ]]; then
	old_inode="$(stat -f %i "$OLD_DIR" 2>/dev/null || stat -c %i "$OLD_DIR")"
	new_inode="$(stat -f %i "$NEW_DIR" 2>/dev/null || stat -c %i "$NEW_DIR")"
	if [[ "$old_inode" != "$new_inode" ]]; then
		c_red "Target already exists and is a different folder: $NEW_DIR"
		exit 1
	fi
fi
note "Target name is free: $NEW_DIR"

# Warn about uncommitted git changes in nested repos (recoverability).
step "1b. Git working-tree status of nested repos (for your awareness)"
while IFS= read -r gitdir; do
	repo="$(dirname "$gitdir")"
	if [[ -n "$(git -C "$repo" status --porcelain 2>/dev/null)" ]]; then
		c_yellow "  uncommitted changes in: ${repo#"$HOME"/}"
	else
		note "clean: ${repo#"$HOME"/}"
	fi
done < <(find "$OLD_DIR" -maxdepth 2 -name .git 2>/dev/null)
note "(Commit anything important first — file edits below are easiest to undo via git.)"

# ---------------------------------------------------------------------------
# Step 2: report / perform the folder rename
# ---------------------------------------------------------------------------
step "2. Rename folder"
note "$OLD_DIR"
note "  -> $NEW_DIR"

if $APPLY; then
	TMP_DIR="$PARENT/.${NEW_NAME}.migrating.$$"
	mv "$OLD_DIR" "$TMP_DIR"
	mv "$TMP_DIR" "$NEW_DIR"
	c_green "Renamed."
	SCAN_DIR="$NEW_DIR"
else
	note "(dry run: not renaming; scanning current location for the report)"
	SCAN_DIR="$OLD_DIR"
fi

# ---------------------------------------------------------------------------
# Step 3: rewrite path references inside text files
# ---------------------------------------------------------------------------
step "3. Rewrite '$OLD_REF' -> '$NEW_REF' in text files"

# -I makes grep skip binary files; -l lists matching files.
# (Read into an array the portable way — macOS ships bash 3.2 without `mapfile`.)
REF_FILES=()
skipped_ignored=0
while IFS= read -r _f; do
	[[ -z "$_f" ]] && continue
	# Skip git-ignored files (live logs, build caches, etc.) — they are
	# volatile/generated and must not be rewritten.
	if is_ignored "$_f"; then
		skipped_ignored=$((skipped_ignored + 1))
		continue
	fi
	REF_FILES+=("$_f")
done < <(grep -rIl "${GREP_EXCLUDES[@]}" "$OLD_REF" "$SCAN_DIR" 2>/dev/null || true)

[[ $skipped_ignored -gt 0 ]] && note "Skipping $skipped_ignored git-ignored file(s) (logs/caches/generated)."

if [[ ${#REF_FILES[@]} -eq 0 ]]; then
	note "No files reference the old path. Nothing to rewrite."
else
	total_lines="$(grep -Ic "$OLD_REF" "${REF_FILES[@]}" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')"
	note "${#REF_FILES[@]} file(s), ~${total_lines} line(s) to update."
	esc_old="$(sed_escape "$OLD_REF")"
	esc_new="$(sed_escape "$NEW_REF")"
	for f in "${REF_FILES[@]}"; do
		if $APPLY; then
			sed_inplace "s|${esc_old}|${esc_new}|g" "$f"
			c_green "  updated: ${f#"$SCAN_DIR"/}"
		else
			note "would update: ${f#"$SCAN_DIR"/}"
		fi
	done
fi

# ---------------------------------------------------------------------------
# Step 4: re-point symlinks whose target contains the old absolute path
# ---------------------------------------------------------------------------
step "4. Fix symlinks pointing at the old path"

# Build a find prune expression from PRUNE_DIRS so we skip node_modules etc.
FIND_PRUNE=()
for d in "${PRUNE_DIRS[@]}"; do
	[[ ${#FIND_PRUNE[@]} -gt 0 ]] && FIND_PRUNE+=(-o)
	FIND_PRUNE+=(-name "$d")
done

found_links=false
while IFS= read -r link; do
	target="$(readlink "$link")"
	case "$target" in
		*"$OLD_REF"*)
			found_links=true
			new_target="${target//$OLD_REF/$NEW_REF}"
			note "${link#"$SCAN_DIR"/}"
			note "    $target"
			note "    -> $new_target"
			if $APPLY; then
				ln -sfn "$new_target" "$link"
				c_green "    re-pointed."
			fi
			;;
	esac
done < <(find "$SCAN_DIR" \( "${FIND_PRUNE[@]}" \) -prune -o -type l -print 2>/dev/null)
$found_links || note "No symlinks needed fixing."

# ---------------------------------------------------------------------------
# Step 5: re-run the dotfiles link installer so $HOME symlinks follow the move
# ---------------------------------------------------------------------------
step "5. Re-link \$HOME dotfiles to the new path"

LINK_SCRIPT="$SCAN_DIR/$LINK_SCRIPT_REL"
if $SKIP_LINKS; then
	note "Skipped (--skip-links)."
elif [[ ! -f "$LINK_SCRIPT" ]]; then
	c_yellow "Link installer not found at: $LINK_SCRIPT (skipping)"
elif $APPLY; then
	note "Running: $LINK_SCRIPT"
	bash "$LINK_SCRIPT"
	c_green "\$HOME dotfile symlinks re-created."
else
	note "(dry run) would run: bash \"$LINK_SCRIPT\""
	note "Preview with: bash \"$LINK_SCRIPT\" --dry-run"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
step "Summary"
if $APPLY; then
	echo
	c_green "Migration complete: $OLD_DIR -> $NEW_DIR"
	cat <<EOF

    Manual follow-ups you may want:
      • Restart your shell (or: exec \$SHELL -l) so the new \$HOME symlinks load.
      • Restart espanso if you use it:   espanso restart
      • Re-open editors/terminals that had the old path open.
      • Check anything OUTSIDE this folder that hardcodes the old path
        (the shell-config hook blocks scripted edits to ~/.zshrc etc., but
        ~/.zshrc here is a symlink into the repo, so step 5 already handled it).
      • Review & commit the edited files in each nested git repo.
EOF
else
	echo
	c_blue "Dry run finished. Re-run with --apply to perform the migration:"
	note "  $0 --apply"
fi
