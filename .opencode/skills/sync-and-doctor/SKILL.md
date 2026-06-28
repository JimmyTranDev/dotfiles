---
name: sync-and-doctor
description: Runs and reasons about this dotfiles repo's install, symlink, and health-check scripts. Use ONLY when working in this dotfiles repo and you need to apply symlinks (sync_links.sh), run the full installer (install.sh), or diagnose the setup (doctor.sh), or when you need to understand the symlink/backup/platform model before changing it. Triggers on "run sync_links", "relink my dotfiles", "run the doctor/health check", "run the installer", "why is a symlink wrong".
---

# Sync, install, and doctor

The setup scripts live in `etc/scripts/src/install/`. They are idempotent and
back up anything they replace, but always dry-run symlinking first.

## The three entry points

| Script | Purpose |
|--------|---------|
| `sync_links.sh [--dry-run]` | Create/refresh all symlinks for the current platform. |
| `install.sh` | Full setup: runs `common.sh` (tools, SDKMAN, links) then the platform script (`mac.sh` / `arch.sh`, `wsl.sh`). Interactive. |
| `doctor.sh` | Read-only health check: tools, symlinks, dirs, git hooks, SSH perms. |

Run with `bash etc/scripts/src/install/<script>.sh`.

## Symlink model (sync_links.sh)

- Link list is built per platform: `get_common_links` + one of
  `get_macos_links` / `get_linux_links` / `get_termux_links`, chosen by
  `get_platform_links` (`is_termux` → Termux, else `uname` Darwin/Linux).
- Each entry is `SOURCE|DEST`. `SOURCE` is under `$DOTFILES_ROOT/src` (or the
  external `$SECRETS_DIR`); `DEST` is where the tool reads from.
- For each entry it: skips if already linked correctly (idempotent), **backs up**
  any existing non-symlink target to `~/.dotfiles-backup/<timestamp>/`, removes
  the target, then `ln -s`.
- After linking it sets `git config --global core.hooksPath` and fixes `~/.ssh`
  permissions (700 dir, 600 key).
- **Always run `--dry-run` first** to preview; it prints "Would link" / "Already
  linked" and a summary without touching the filesystem.

```bash
bash etc/scripts/src/install/sync_links.sh --dry-run   # preview
bash etc/scripts/src/install/sync_links.sh             # apply
```

## Health check (doctor.sh)

- Verifies required tools (git, nvim, fzf, rg, fd, starship, zellij, yazi,
  lazygit, bat, jq; plus brew/yabai/skhd on macOS), optional tools, every
  symlink in its `SYMLINKS` array, required dirs, git hooks path, and SSH perms.
- Exit code: `1` if any check **failed**, `0` otherwise (warnings allowed).
- It is read-only and safe to run anytime. On failure it points back at
  `install.sh`.

```bash
bash etc/scripts/src/install/doctor.sh
```

## Secrets

Secrets are **not** in this repo. They live at
`~/Programming/JimmyTranDev/secrets` and are linked in as `~/.ssh`,
`~/.gitconfig`, `~/.npmrc`, `~/.m2`, and the espanso personal match. If that
directory is absent, those links are skipped (sync) or reported as warnings
(doctor) — that is expected on a machine without the secrets repo.

## When changing the link set

`sync_links.sh` and `doctor.sh` both enumerate links and must stay in sync. Use
the `add-tool-config` skill for the full add/rename/remove workflow.

## Verify

- After `sync_links.sh`: run `doctor.sh` — all symlink checks pass.
- Never delete a backup under `~/.dotfiles-backup/` without confirming the user
  no longer needs the replaced file.
- Do not run `install.sh` non-interactively expecting silence — it prompts
  (`</dev/tty`) for yazi/pipx/pnpm/storecode steps.
