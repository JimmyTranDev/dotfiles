---
name: dotfiles-shell-scripts
description: Writes or edits Bash scripts under etc/scripts/ in this dotfiles repo following the repo's conventions. Use ONLY when authoring or modifying a shell script in this dotfiles repo — its install/setup/utility scripts source shared logging and utility helpers and follow a strict structure. Triggers on "add a script", "edit the install script", "new helper under etc/scripts", "follow the dotfiles shell conventions".
---

# Shell scripts in the dotfiles repo

All scripts live under `etc/scripts/` and share a house style. Match it exactly —
inconsistent scripts break sourcing and the logging output.

## Layout

```
etc/scripts/
├── consts/        # colors.sh, emoji.sh, dirs.sh  (constants only)
├── utils/         # logging.sh, utility.sh, git.sh, jira.sh, json.sh, detect.sh, ...
└── src/           # actual scripts: install/, worktrees/, zellij/, ai/, ...
```

- `consts/` and `utils/` are **sourced**, never executed.
- `src/<area>/` holds runnable scripts grouped by purpose.

## Script template

```bash
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/../.."          # adjust depth to reach etc/scripts

source "$SCRIPTS_DIR/utils/logging.sh"
source "$SCRIPTS_DIR/utils/utility.sh"   # only if you use its helpers

main() {
	log_header "Doing the thing..."
	# ...
	log_success "Done"
}

main "$@"
```

- Shebang `#!/bin/bash`. Use `set -e`; use `set -eo pipefail` when piping
  matters (see `doctor.sh`).
- Compute `SCRIPT_DIR` from `${BASH_SOURCE[0]}`; derive other paths from it.
  Never hardcode `/Users/...` — derive from `$HOME`, `$SCRIPT_DIR`, or the
  computed `DOTFILES_ROOT`/`DOTFILES_DIR`.
- Structure as functions with a `main()` that runs last via `main "$@"`.
- **Indent with tabs** (the existing scripts do).

## Logging (do not raw-echo user messages)

Source `utils/logging.sh` and use these — they write to **stderr** with color +
emoji:

| Helper | Use for |
|--------|---------|
| `log_info "msg"` | neutral progress |
| `log_success "msg"` | a step completed |
| `log_warning "msg"` | recoverable problem |
| `log_error "msg"` | failure (often before `exit 1`) |
| `log_header "msg" [emoji]` | section banner |

Reserve bare `echo` to **stdout** for machine-readable output that another
script will capture/pipe (e.g. emitting paths). User-facing chatter goes through
`log_*`.

## Reuse existing helpers (utils/utility.sh)

Before writing new logic, check for an existing helper:

- `require_tool foo bar` — assert commands exist (returns non-zero if missing).
- `slugify "Some Text"` — lowercase, hyphenated slug.
- `get_org_dirs [dir]` — org folders under `~/Programming` (honours
  `PROGRAMMING_EXCLUDED_DIRS` from `consts/dirs.sh`).
- `find_git_repos`, `find_git_worktrees`, `find_git_repos_and_worktrees`,
  `find_git_worktrees_categorized`, `get_worktree_project_name` — repo/worktree
  discovery.
- `reorder_last_first`, `_fzf_select_items_and_cd` — fzf selection helpers.

Constants come from `consts/`: `colors.sh` (`$RED`,`$GREEN`,`$NC`,...),
`emoji.sh` (`$EMOJI_SUCCESS`,`$EMOJI_LINK`,...), `dirs.sh`.

## Conventions

- Platform detection: `is_termux`, `[ "$(uname)" == "Darwin" ]`,
  `[ "$(uname)" == "Linux" ]` (and `/etc/arch-release`, `grep -qi microsoft
  /proc/version` for WSL — see `install.sh`).
- Interactive prompts read from the terminal explicitly:
  `read -rp "Do X? [y/N] " answer </dev/tty`.
- Make new scripts executable (`chmod +x`); `common.sh` also chmods the tree on
  install.
- Quote every path expansion (`"$var"`), especially destinations that may
  contain spaces (macOS "Application Support").

## Verify

- `bash -n script.sh` (syntax) and `shellcheck script.sh` if available.
- Run with `--help` and, for anything destructive, a `--dry-run` path first.
- Confirm `source`-only files (`consts/`, `utils/`) have no top-level side
  effects beyond defining vars/functions.
