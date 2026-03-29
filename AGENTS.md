## Critical Code Writing Rule
**NO COMMENTS POLICY**: When writing, modifying, or generating code, do NOT add any comments. Write clean, self-documenting code with clear variable names, function names, and code structure that makes the intent obvious without explanatory comments. Comments clutter code, become outdated, and can mislead. Focus on readability through code structure, not comments.

## Universal Rules

- **Match existing conventions** — before writing new code, examine the surrounding codebase and follow its patterns exactly. Never introduce new conventions without explicit instruction.
- **Never create documentation files** (README, docs, markdown) unless explicitly asked.
- **Prefer editing over creating** — always modify existing files rather than creating new ones when possible.
- **Catppuccin Mocha** is the unified color theme across all tools.

## Repository Structure

```
dotfiles/
├── src/                    # Config files (symlinked to their destinations)
│   ├── opencode/           # -> ~/.config/opencode/
│   ├── ghostty/            # -> ~/.config/ghostty/
│   ├── kitty/              # -> ~/.config/kitty/
│   ├── yazi/               # -> ~/.config/yazi/
│   ├── zellij/             # -> ~/.config/zellij/
│   ├── lazygit/            # -> ~/.config/lazygit/
│   ├── btop/               # -> ~/.config/btop/
│   ├── skhd/               # -> ~/.config/skhd/ (macOS only)
│   ├── yabai/              # -> ~/.config/yabai/ (macOS only)
│   ├── hypr/               # -> ~/.config/hypr/ (Linux only)
│   ├── git/hooks/          # -> ~/.config/git/hooks/
│   ├── .zshrc              # -> ~/.zshrc
│   ├── .ideavimrc          # -> ~/.ideavimrc
│   ├── .gitignore_global   # -> ~/.gitignore_global
│   ├── starship.toml       # -> ~/.config/starship.toml
│   └── Brewfile            # -> ~/Brewfile (macOS only)
├── etc/
│   ├── scripts/            # Setup and utility scripts
│   │   ├── common/         # Shared shell utilities (logging, git helpers)
│   │   ├── install/        # Platform-specific install scripts (mac, arch, common)
│   │   ├── sync_links.sh   # Creates symlinks from src/ to destinations
│   │   ├── install.sh      # Main install entry point
│   │   └── doctor.sh       # Health check script
│   ├── templates/          # Template configs (.gitconfig, .npmrc, .m2)
│   ├── docs/               # Setup guides (mac, wsl, common)
│   └── theme.conf          # Catppuccin Mocha theme reference
└── .gitignore
```

## How Symlinks Work

`etc/scripts/sync_links.sh` maps each `src/` entry to its destination via `ln -s`. Run it directly or via `install.sh`. Platform detection (`uname`) determines which links apply (macOS includes skhd/yabai/ghostty/Brewfile; Linux includes hypr). Neovim config lives in a separate repo at `~/Programming/JimmyTranDev/nvim` and is linked to `~/.config/nvim`.

## Working with This Repo

- **Adding a new tool config**: Create a directory under `src/`, add it to the appropriate `get_macos_links()` or `get_linux_links()` function in `sync_links.sh`, then run the script.
- **Shell scripts**: All scripts use bash, source `common/logging.sh` and `common/utility.sh` for shared functions. Follow the existing pattern of `set -e`, function-based structure, and the logging helpers (`log_info`, `log_success`, `log_warning`, `log_error`).
- **OpenCode config**: `src/opencode/` contains agents, commands, skills, and `AGENTS.md` (global LLM rules). The `opencode.json` loads `agent/*.md`, `command/*.md`, and `AGENTS.md` via its `instructions` array. Skills at `skills/<name>/SKILL.md` are auto-discovered. Deprecated items are moved to `_depreciated/` subdirectories within `command/` and `skills/` — they are excluded from auto-discovery.

```
src/opencode/
├── AGENTS.md               # Global LLM rules (no-comments, parallelization, etc.)
├── opencode.json            # OpenCode project config
├── tui.json                 # TUI appearance config
├── agent/                   # Specialized subagents
│   ├── auditor.md
│   ├── browser.md
│   ├── designer.md
│   ├── fixer.md
│   ├── optimizer.md
│   ├── reviewer.md
│   └── tester.md
├── command/                 # Slash commands (/name)
│   ├── _depreciated/        # Retired commands
│   ├── agents-md.md
│   ├── chat.md
│   ├── clean.md
│   ├── comments.md
│   ├── commit.md
│   ├── commit-push.md
│   ├── consolidate.md
│   ├── convention.md
│   ├── conventions.md
│   ├── gitignore.md
│   ├── implement.md
│   ├── implement-stitch.md
│   ├── init.md
│   ├── innovate.md
│   ├── jira.md
│   ├── npm-audit.md
│   ├── quality.md
│   ├── review.md
│   ├── suggest.md
│   ├── stitch.md
│   └── ux.md
└── skills/                  # On-demand knowledge (auto-discovered)
    ├── _depreciated/        # Retired skills
    ├── accessibility/
    ├── agents-md/
    ├── browser-mcp/
    ├── career/
    ├── consolidator/
    ├── conventions/
    ├── deduplicator/
    ├── eslint-config/
    ├── follower/
    ├── fsrs/
    ├── gamification/
    ├── git-workflows/
    ├── innovate/
    ├── mobile-mcp/
    ├── npm-vulnerabilities/
    ├── opencode-authoring/
    ├── shell-scripting/
    ├── simplifier/
    ├── stitch/
    ├── todoist-cli/
    ├── ux-ui-animator/
    └── worktree-workflow/
```
