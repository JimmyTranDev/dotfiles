# CLAUDE.md — dotfiles (project scope)

Project rules for working **on this dotfiles repo**. Loaded via
`.opencode/opencode.json` (`instructions: ["CLAUDE.md"]`). The repo-root
`CLAUDE.md` carries the universal rules and the full directory tree — read it
for structure; this file routes work to the project skills and states the
invariants that are easy to break.

## Project skills

These skills live in `.opencode/skills/<name>/SKILL.md` and are auto-discovered.
Invoke the matching one with the `skill` tool before acting.

| Intent | Skill |
|--------|-------|
| Add/manage a tool's config so it gets symlinked into place | `add-tool-config` |
| Write or edit a shell script under `etc/scripts/` | `dotfiles-shell-scripts` |
| Run install / sync_links / doctor, or reason about the symlink model | `sync-and-doctor` |
| Edit the Neovim config under `src/nvim` (keymaps, actions, plugins, lint) | `nvim-config` |
| Edit the Zellij config under `src/zellij` (keybinds, KDL layouts, theme) | `zellij-config` |

The global skill set (from `~/.config/opencode/skills`, e.g. `commit`,
`git-workflow-and-versioning`, `code-review-and-quality`) still applies. When a
global lifecycle skill and a project skill both fit, run the project skill for
the repo-specific mechanics.

## Invariants (do not break these)

- **Symlink model.** `src/<tool>/` is the source of truth; it is symlinked to a
  destination by `etc/scripts/src/install/sync_links.sh`. Never edit the live
  `~/.config/...` target directly — edit the file under `src/` instead.
- **Two places stay in sync.** A managed link is registered in **both**
  `sync_links.sh` (the `get_*_links()` functions) **and** `doctor.sh` (the
  `SYMLINKS` array). Add/rename/remove in both, in the matching platform block.
- **Platform correctness.** Links are split across `get_common_links`,
  `get_macos_links`, `get_linux_links`, and `get_termux_links`. Put each link in
  the narrowest correct bucket (macOS-only tools like `skhd`/`yabai`/`ghostty`
  go in macОС; `hypr` is Linux-only).
- **Secrets live outside the repo** at `~/Programming/JimmyTranDev/secrets`
  (linked in as `~/.ssh`, `~/.gitconfig`, `~/.npmrc`, `~/.m2`, ...). Never commit
  secrets or hardcode their contents into the repo.
- **Shell conventions.** Scripts use `#!/bin/bash`, `set -e`, a `SCRIPT_DIR`
  computed from `BASH_SOURCE`, source `utils/logging.sh` (+ `utils/utility.sh`),
  log via `log_info/log_success/log_warning/log_error/log_header`, are
  function-based, and end with `main "$@"`. Indent with tabs.
- **Catppuccin Mocha** is the unified theme across every tool.
- **Never create documentation files** (README/markdown/docs) unless explicitly
  asked. Updating the structure tree in the root `CLAUDE.md` after adding a tool
  is allowed.

## Verify before done

- Symlink changes: `etc/scripts/src/install/sync_links.sh --dry-run` is clean,
  then `etc/scripts/src/install/doctor.sh` passes.
- Shell scripts: run with `--help`/`--dry-run` where supported; `shellcheck` if
  available.
- Neovim: `selene` is clean (config at `src/nvim/selene.toml`).
