# Jimmy's Dotfiles

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Shell](https://img.shields.io/badge/Shell-Zsh-blue.svg?style=flat-square&logo=gnu-bash)](https://www.zsh.org)
[![macOS](https://img.shields.io/badge/macOS-Supported-000000.svg?style=flat-square&logo=apple)](https://www.apple.com/macos)
[![Linux](https://img.shields.io/badge/Linux-Supported-FCC624.svg?style=flat-square&logo=linux&logoColor=black)](https://archlinux.org)
[![Theme](https://img.shields.io/badge/Theme-Catppuccin_Mocha-b4befe.svg?style=flat-square)](https://catppuccin.com)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg?style=flat-square)](LICENSE)

A terminal-first development environment with AI-powered coding agents, 36 Neovim plugins, tiling windows, and a unified Catppuccin Mocha theme — all deployed with a single command.

<!-- TODO: Add hero screenshot showing full desktop: Ghostty terminal with Zellij panes, Neovim open with LSP completion visible, Lazygit in a side pane, Yabai tiling everything cleanly. Save to .github/assets/hero.png -->

## Why This Repo

- **One command, full environment** — `./etc/scripts/install.sh` detects your platform, installs packages, symlinks configs, and sets up SDKs. Zero manual steps.
- **AI-first development** — 17 specialized agents, 46 commands, 99 skills, and 25 reusable scripts that turn your terminal into an autonomous coding environment.
- **Unified aesthetic** — Catppuccin Mocha across every tool. Terminal, editor, prompt, file manager, git TUI, window manager. One palette, zero visual friction.
- **Reproducible** — Same environment on any Mac or Arch Linux box. Clone, install, done.
- **Modular** — Each tool's config is independent. Swap out any piece without touching the rest.

## Preview

<!-- TODO: Add terminal recording (VHS/asciinema) showing: clone repo → run install → open neovim with LSP → run an OpenCode /commit command. Save to .github/assets/demo.gif -->

<details>
<summary><strong>Neovim</strong> — LSP, completion, treesitter, 36 plugins</summary>

<!-- TODO: Screenshot of Neovim with LSP completion dropdown, treesitter highlighting, and gitsigns in the gutter. Save to .github/assets/neovim.png -->

</details>

<details>
<summary><strong>Terminal</strong> — Ghostty + Zellij + Starship</summary>

<!-- TODO: Screenshot of Ghostty with Zellij layout (multiple panes), Starship prompt showing git branch/status. Save to .github/assets/terminal.png -->

</details>

<details>
<summary><strong>Git</strong> — Lazygit + Fugitive + AI commits</summary>

<!-- TODO: Screenshot of Lazygit with staged changes, branch list visible. Save to .github/assets/lazygit.png -->

</details>

<details>
<summary><strong>AI Workflow</strong> — OpenCode agents in action</summary>

<!-- TODO: Screenshot of OpenCode running /implement or /review command with agent output visible. Save to .github/assets/opencode.png -->

</details>

<details>
<summary><strong>Window Management</strong> — Yabai tiling on macOS</summary>

<!-- TODO: Screenshot of Yabai tiling 3-4 windows cleanly across the screen. Save to .github/assets/yabai.png -->

</details>

## Quick Start

```bash
git clone https://github.com/JimmyTranDev/dotfiles.git
cd dotfiles
./etc/scripts/install.sh
```

Run `./etc/scripts/doctor.sh` afterward to verify everything is healthy.

## What's Inside

### Editing

**Neovim** with 36 plugins — LSP for every language, blink.cmp completion, treesitter highlighting, telescope fuzzy finding, and custom Lua actions for git, Jira, Todoist, and more. Full config lives in `src/nvim/`.

### Git

**Lazygit** for interactive staging and rebasing. **Fugitive** and **Gitsigns** inside Neovim. Custom OpenCode `/commit`, `/pr`, and `/merge` commands that handle worktrees, conventional commits, and PR creation automatically.

### Terminal

**Ghostty** (GPU-accelerated) + **Zellij** (multiplexer with custom layouts) + **Starship** (blazing-fast prompt with git/language info). All Catppuccin Mocha themed.

### Navigation

**Yazi** terminal file manager with image preview, bookmarks, and plugins. **Telescope** inside Neovim for file/grep/buffer/symbol search.

### Window Management

**Yabai** tiling window manager + **SKHD** hotkey daemon on macOS. Automatic tiling, space management, and focus-follows-mouse.

### AI-Powered Development

This is the differentiator. The `src/opencode/` directory contains a full AI development environment:

| Resource | Count | What it does |
|----------|-------|--------------|
| **Agents** | 17 | Specialized subagents — auditor, reviewer, fixer, implementer, optimizer, tester, designer, and more |
| **Commands** | 46 | Orchestrated workflows — `/implement`, `/pr`, `/review`, `/specify`, `/fix`, `/commit`, `/weekly-summary` |
| **Skills** | 99 | On-demand knowledge — Spring Boot, Expo, Drizzle, security, testing, system design, career strategy |
| **Scripts** | 25 | Reusable shell tools — stack detection, branch info, test runners, PR status, migration checks |

**Example workflows:**

```bash
/specify security src/api/     # Generates a security audit spec in plans/
/implement plans/auth-fix.md   # Implements the spec with agents, tests, and review
/pr                            # Creates worktree, implements, reviews, opens PR
/commit                        # Analyzes diff, writes conventional commit message
```

Agents delegate to each other — the reviewer finds issues, the fixer resolves them, the tester verifies. Skills inject domain knowledge (Spring Boot patterns, React conventions, Zod schemas) so agents write idiomatic code.

## Scripts

```bash
./etc/scripts/install.sh       # Full setup (detects platform, installs everything)
./etc/scripts/sync_links.sh    # Symlink configs (supports --dry-run)
./etc/scripts/doctor.sh        # Health check (validates symlinks, tools, env)
./etc/scripts/sdk_install.sh   # Install SDK versions (Java, Go, etc.)
./etc/scripts/sdk_select.sh    # Switch between installed SDK versions
```

The `etc/scripts/src/ai/` directory contains 25 reusable scripts that replace repetitive multi-step operations: `detect-stack.sh`, `git-branch-info.sh`, `run-tests.sh`, `lint-check.sh`, `pr-status.sh`, `security-scan.sh`, and more.

<details>
<summary><strong>Repository Structure</strong></summary>

```
src/                     # Configs (symlinked to ~/.config or ~/)
├── nvim/                # Neovim — 36 plugins, LSP, custom actions
├── opencode/            # AI coding — 17 agents, 46 commands, 99 skills
├── ghostty/             # Terminal emulator
├── zellij/              # Multiplexer
├── lazygit/             # Git TUI
├── yazi/                # File manager
├── kitty/               # Alt terminal
├── skhd/                # Hotkeys (macOS)
├── yabai/               # Tiling WM (macOS)
├── .zshrc               # Shell config
├── starship.toml        # Prompt
└── Brewfile             # Homebrew packages

etc/
├── scripts/             # Install, sync, health check, SDK management
│   ├── common/          # Shared utilities (logging, git helpers)
│   ├── install/         # Platform-specific installers
│   └── src/ai/          # 25 reusable AI utility scripts
├── templates/           # Template configs (.gitconfig, .npmrc)
├── docs/                # Setup guides
└── theme.conf           # Catppuccin Mocha reference
```

</details>

## Theme

Every tool uses **Catppuccin Mocha**. Terminal, editor, prompt, multiplexer, file manager, git TUI, window manager. One palette, consistent everywhere.

## License

Apache 2.0
