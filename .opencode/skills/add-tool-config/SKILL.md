---
name: add-tool-config
description: Adds or manages a tool's dotfiles in this dotfiles repo so it gets symlinked into place. Use ONLY when working in this dotfiles repo and you need to start managing a new tool's config (create src/<tool>/, register the link in sync_links.sh, mirror it in doctor.sh), rename, or remove a managed config. Triggers on "add a config for <tool>", "manage <tool> with dotfiles", "symlink <tool>'s config", "stop managing <tool>".
---

# Add a tool config to the dotfiles repo

The repo manages configs by **symlinking** `src/<tool>/` to the location the
tool expects. Two files describe every managed link and must stay in sync:

- `etc/scripts/src/install/sync_links.sh` — creates the links (`get_*_links()`).
- `etc/scripts/src/install/doctor.sh` — verifies the links (`SYMLINKS` array).

Adding a tool means putting its files under `src/` and registering the link in
both files, in the correct platform bucket.

## Workflow

1. **Create the source.** Add the config under `src/<tool>/` (a directory) or
   `src/<file>` (a single dotfile). Use the real config content; match Catppuccin
   Mocha theming where the tool supports a theme.

2. **Find the destination** the tool reads from. Common shapes:
   - XDG dir: `$HOME/.config/<tool>`
   - Home dotfile: `$HOME/.<file>`
   - macOS app support: `$HOME/Library/Application Support/<tool>`

3. **Pick the platform bucket** in `sync_links.sh`:
   | Applies to | Function |
   |------------|----------|
   | All platforms (mac, linux, termux share it) | `get_common_links` |
   | macOS only (skhd, yabai, ghostty, Brewfile, mac app-support paths) | `get_macos_links` |
   | Linux only (hypr, linux app-support paths) | `get_linux_links` |
   | Android/Termux | `get_termux_links` |

   `get_macos_links` and `get_linux_links` call `get_common_links` first, so put
   cross-platform tools in `get_common_links` only — never duplicate.

4. **Add the link entry.** Format is `SOURCE|DEST`, one per line, inside the
   `local links=( ... )` array:
   ```bash
   "$DOTFILES_ROOT/src/<tool>|$HOME/.config/<tool>"
   ```
   For paths with spaces, keep the whole entry quoted:
   ```bash
   "$DOTFILES_ROOT/src/lazysql|$HOME/Library/Application Support/lazysql"
   ```

5. **Mirror it in `doctor.sh`.** Add a matching entry to the `SYMLINKS` array
   (note: `doctor.sh` orders each entry as `DEST|SOURCE`), in the same platform
   block (`if [ "$(uname)" = "Darwin" ]` / `Linux`). Keep wording/paths identical
   to `sync_links.sh` so the health check is meaningful.

6. **Dry-run, then apply.** `bash etc/scripts/src/install/sync_links.sh --dry-run`
   and confirm it reports your tool. Then run it without `--dry-run`. See the
   `sync-and-doctor` skill for details on the symlink/backup model.

7. **Verify.** `bash etc/scripts/src/install/doctor.sh` should report
   `Symlink <tool> -> correct target`.

8. **Update the structure tree** in the repo-root `AGENTS.md` if the new tool is
   worth listing there (allowed even under the no-docs rule — it is repo metadata,
   not new documentation).

## Rules

- Edit files under `src/` — never the live target. After linking, the target IS
  the repo file; editing the target edits the repo (confusing) — always go
  through `src/`.
- A link belongs in exactly one bucket. If both mac and linux need it but termux
  does not, it still goes in `get_common_links` (termux has its own explicit
  list) — re-check `get_termux_links` and add it there too only if wanted.
- Secrets are not tool configs: anything under `~/Programming/JimmyTranDev/secrets`
  is linked separately and must never be copied into `src/`.

## Verification checklist

- [ ] Files exist under `src/<tool>/`.
- [ ] Link entry added to the correct `get_*_links()` in `sync_links.sh`.
- [ ] Matching entry added to `SYMLINKS` in `doctor.sh` (same platform block).
- [ ] `sync_links.sh --dry-run` lists the tool and is otherwise clean.
- [ ] `doctor.sh` passes for the new symlink.
- [ ] Root `AGENTS.md` tree updated if the tool was added to the documented set.
