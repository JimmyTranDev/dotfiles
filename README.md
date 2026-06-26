# Jimmy's Dotfiles

[![Neovim](https://img.shields.io/badge/Neovim-0.10+-57A143.svg?style=flat-square&logo=neovim)](https://neovim.io)
[![Shell](https://img.shields.io/badge/Shell-Zsh-blue.svg?style=flat-square&logo=gnu-bash)](https://www.zsh.org)
[![macOS](https://img.shields.io/badge/macOS-Supported-000000.svg?style=flat-square&logo=apple)](https://www.apple.com/macos)
[![Linux](https://img.shields.io/badge/Linux-Supported-FCC624.svg?style=flat-square&logo=linux&logoColor=black)](https://archlinux.org)
[![Theme](https://img.shields.io/badge/Theme-Catppuccin_Mocha-b4befe.svg?style=flat-square)](https://catppuccin.com)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg?style=flat-square)](LICENSE)

> **A whole terminal-first dev environment that sets itself up in one command.**
> Neovim wired for every language, AI workflows living inside the shell, tiling
> windows that arrange themselves, and a single Catppuccin Mocha palette holding
> it all together.

Clone it on a fresh Mac or Arch box, run one script, grab a coffee — by the time
you're back, the machine feels like home: **36 Neovim plugins**, AI-powered
coding workflows, and a terminal that looks as good as it works.

<!-- TODO: Add hero screenshot showing full desktop: Ghostty terminal with Zellij panes, Neovim open with LSP completion visible, Lazygit in a side pane, Yabai tiling everything cleanly. Save to .github/assets/hero.png -->

## ✨ Why This Repo

- **⚡ One command, whole machine** — `install.sh` detects your platform,
  installs packages, symlinks every config, and sets up SDKs. No checklists, no
  "step 7 of 23." Just run it.
- **🤖 AI baked into the terminal** — 9 orchestrated commands, 43 on-demand
  skills, 3 editor plugins, and 35 helper scripts turn your shell into an
  autonomous coding teammate.
- **🎨 One palette, everywhere** — Catppuccin Mocha across terminal, editor,
  prompt, file manager, git TUI, and window manager. Switch tools all day and
  never switch context.
- **♻️ Reproducible** — The same environment on any Mac or Arch Linux box. Clone,
  install, done. Your muscle memory travels with you.
- **🧩 Modular** — Every tool's config stands on its own. Rip out any piece and
  the rest keeps humming.

## 👀 Preview

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
<summary><strong>Git</strong> — Lazygit + AI commits</summary>

<!-- TODO: Screenshot of Lazygit with staged changes, branch list visible. Save to .github/assets/lazygit.png -->

</details>

<details>
<summary><strong>AI Workflow</strong> — OpenCode commands in action</summary>

<!-- TODO: Screenshot of OpenCode running /implement or /review-pr command with output visible. Save to .github/assets/opencode.png -->

</details>

<details>
<summary><strong>Window Management</strong> — Yabai tiling on macOS</summary>

<!-- TODO: Screenshot of Yabai tiling 3-4 windows cleanly across the screen. Save to .github/assets/yabai.png -->

</details>

## ⚡ Quick Start

```bash
git clone https://github.com/JimmyTranDev/dotfiles.git
cd dotfiles
./etc/scripts/src/install/install.sh
```

Then run `./etc/scripts/src/install/doctor.sh` to confirm everything is wired up
and healthy. That's the whole setup.

## 📦 What's Inside

### ✍️ Editing

**Neovim** with 36 plugins — LSP for every language (via mason-lspconfig),
[blink.cmp](https://github.com/Saghen/blink.cmp) completion, treesitter
highlighting, [snacks.nvim](https://github.com/folke/snacks.nvim) fuzzy picker,
and custom Lua actions for git, Jira, Todoist, and more. Full config lives in
`src/nvim/`.

### 🌳 Git

**Lazygit** for interactive staging and rebasing, with **Gitsigns**
right inside Neovim. Custom OpenCode `/commit`, `/implement-pr`, and
`/merge-worktrees` commands handle worktrees, conventional commits, and PR
creation so you stay in flow.

### 🖥️ Terminal

**Ghostty** (GPU-accelerated) + **Zellij** (multiplexer with custom layouts) +
**Starship** (a blazing-fast prompt with git and language context) — with
**Kitty** kept around as a drop-in alternative. All Catppuccin Mocha themed.

### 🧭 Navigation

**Yazi** terminal file manager with image preview, bookmarks, and plugins.
Inside Neovim, the **snacks.nvim** picker handles file, grep, buffer, and symbol
search — fuzzy-finding without leaving the keyboard.

### 🪟 Window Management

**Yabai** tiling window manager + **SKHD** hotkey daemon on macOS, and
**Hyprland** on Linux. Automatic tiling, space management, and
focus-follows-mouse — your windows arrange themselves.

### 🤖 AI-Powered Development

This is the differentiator. The `src/opencode/` directory is a full AI
development environment built on [OpenCode](https://opencode.ai):

| Resource | Count | What it does |
|----------|-------|--------------|
| **Commands** | 9 | Orchestrated workflows — `/implement`, `/implement-pr`, `/implement-worktree`, `/review-pr`, `/spec-plan`, `/commit`, `/fix`, `/merge-worktrees`, `/audit-npm` |
| **Skills** | 43 | On-demand expertise — test-driven development, security hardening, spec-driven development, debugging, code review, Figma-to-code, Turso, and more |
| **Plugins** | 2 | Custom JS plugins — live Zellij pane/tab status |
| **Scripts** | 35 | Reusable shell tools — stack detection, branch info, test runners, PR status, security scans, and more |

There are no bespoke "agents" to babysit. Instead, a single `AGENTS.md` rule file
routes every request to the right **skill**, **commands** drive multi-phase
workflows (spec → plan → build → verify → review), and **skills** inject
just-in-time domain knowledge (TDD discipline, idiomatic API design, security
checklists) so the model writes idiomatic code.

**Example workflows:**

```bash
/spec-plan add rate limiting to the API   # Produce a spec + ordered task plan, then stop
/implement ABC-123                         # Run a ticket end-to-end in place (spec → review)
/implement-pr add a dark-mode toggle       # Same flow, in a worktree, ending in a pull request
/commit                                    # Conventional commit from your staged changes
/audit-npm                                 # Bump deps to latest minor, re-audit, prove it's green
```

## 🛠️ Scripts

```bash
./etc/scripts/src/install/install.sh       # Full setup (detects platform, installs everything)
./etc/scripts/src/install/sync_links.sh    # Symlink configs (supports --dry-run)
./etc/scripts/src/install/doctor.sh        # Health check (validates symlinks, tools, env)
./etc/scripts/src/sdk_install.sh           # Install SDK versions (Java, Go, etc.)
./etc/scripts/src/sdk_select.sh            # Switch between installed SDK versions
```

The `etc/scripts/src/ai/` directory holds 35 reusable scripts that collapse
repetitive multi-step chores into one call: `detect-stack.sh`,
`git-branch-info.sh`, `run-tests.sh`, `lint-check.sh`, `pr-status.sh`,
`security-scan.sh`, and more.

<details>
<summary><strong>Repository Structure</strong></summary>

```
src/                          # Configs (symlinked to ~/.config or ~/)
├── nvim/                     # Neovim — 36 plugins, LSP, custom Lua actions
├── opencode/                 # AI coding — 9 commands, 43 skills, 3 plugins
├── ghostty/  kitty/          # Terminal emulators
├── zellij/                   # Multiplexer
├── lazygit/ lazydocker/ lazysql/   # TUIs (git, docker, SQL)
├── yazi/                     # File manager
├── skhd/  yabai/             # Hotkeys + tiling WM (macOS)
├── hypr/                     # Tiling WM (Linux)
├── git/  ssh/                # Git hooks/configs + SSH config
├── .zshrc  starship.toml     # Shell + prompt
└── Brewfile                  # Homebrew packages

etc/
├── scripts/
│   ├── src/install/          # install.sh, sync_links.sh, doctor.sh, platform installers
│   ├── src/ai/               # 35 reusable AI utility scripts
│   ├── utils/                # Shared utilities (logging, helpers)
│   └── tests/                # Script tests
├── docs/                     # Setup guides
└── theme.conf               # Catppuccin Mocha reference
```

</details>

## 🎨 Theme

Every tool wears **Catppuccin Mocha** — terminal, editor, prompt, multiplexer,
file manager, git TUI, and window manager. One palette, zero visual friction, the
same calm colors wherever you look.

## 📄 License

[Apache 2.0](LICENSE) — use it, fork it, make it yours.
