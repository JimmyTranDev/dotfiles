# Migrating Toggleterm logic to Zellij

> How to move the Neovim **toggleterm.nvim** terminal workflow (`<leader>t*`)
> out of the editor and into **Zellij** panes/tabs driven by launcher scripts.

## Why migrate

Today every command runner lives *inside* one nvim instance via
`toggleterm.nvim`. That couples the terminal lifecycle to the editor:

- Terminals die when nvim exits; state is per-editor and invisible to other nvims.
- Reading output needs a dedicated RPC bridge (`nvim-toggleterm-read` skill).
- Long-running jobs (Spring Boot, `mvn`, dev servers) compete with the editor UI.

Zellij already owns the session, panes, tabs, and sizing. Moving the runners
into Zellij makes jobs:

- **Session-scoped** — survive nvim restarts, visible to every editor in the tab.
- **Directly readable** — `zellij action dump-screen` / pane focus, no RPC.
- **First-class panes** — real splits, stacking, fullscreen, named tabs.

---

## Current state (what we're moving)

### Toggleterm side (source of truth today)

| File | Role |
|------|------|
| `src/nvim/lua/plugins/toggleterm.lua` | All `<leader>t*` keybinds + plugin `setup()` |
| `src/nvim/lua/custom/utils/terminal_registry.lua` | Named-terminal registry (create/get_or_create/restart/toggle/kill/kill_all/list) |
| `src/nvim/lua/custom/actions/toggleterm.lua` | Terminal picker UI, blank terminal, kill-all |
| `src/nvim/lua/custom/actions/language.lua` | npm/make/maven command runners |
| `src/nvim/lua/custom/actions/pnpm.lua` | `pnpm link` / `unlink` |
| `src/opencode/skills/nvim-toggleterm-read/` | Read-only RPC reader (`scripts/nvim-term.sh`) |

**The registry model** (`terminal_registry.lua`): terminals are keyed by a
unique name (auto-slugified from the command, e.g. `make start` → `make-start`).
`get_or_create(name, opts)` toggles an existing live terminal or spawns a new
one; `restart` force-respawns; `close_on_exit` defaults to **false** (output
stays on screen after the job ends). This naming + "reuse if alive, else spawn"
behaviour is the core thing to replicate in Zellij.

**Keybind inventory** (all `<leader>t*`, normal mode):

- Lifecycle: `tf` picker · `tt` blank term · `tx` kill all
- npm/pnpm: `tnum/tnun/tnup/tnui` update · `tni` install · `tnj` run script ·
  `tnm` multi-select (≤6 parallel) · `tnM` kill those · `tnf` `fms:types` ·
  `tna` build+lint+test · `tny`/`tnY` pnpm link/unlink
- make: `tmj` pick target · `tms` `make start`
- maven/java: `tvs` run jar/Spring · `tvp` package · `tvt` test · `tvf` test
  current file · `tvc` coverage · `tvn` coverage (changed) · `tvN` diff-cover ·
  `tvb` compile
- database: `tds` start PostgreSQL · `tdr` reset DB

### Zellij side (the target platform)

| File | Role |
|------|------|
| `src/zellij/config.kdl` | Locked-mode, `Alt`-prefixed keybinds; many `Run` shell-outs |
| `src/zellij/layouts/opencode-sidebar.kdl` | `Alt p` — 30% chosen-tool sidebar + 70% nvim main pane |
| `etc/scripts/src/zellij/open_ai_chat.sh` | `Alt ]` — open the repo's AI chat (opencode/storecode), no prompts |
| `etc/scripts/src/zellij/open_project_tool.sh` | `Alt p` — pick project + tool → open the 30% tool / 70% nvim sidebar layout in a new tab |
| `etc/scripts/src/zellij/update_tab_indexes.sh` | Re-prefix tab names (`1.foo`, `2.bar`) |
| `etc/scripts/utils/utility.sh` | Shared helpers (see below) |

**Reusable helpers already in `utility.sh`** — the migration builds on these:

- `select_pane_tool` — fzf picker over `PANE_TOOLS`, remembers last choice.
- `current_pane_dir` — abs cwd of the focused pane (parses `dump-layout`).
- `last_project_dir` / `select_project_dir` — project dir fallbacks.
- `open_tool_pane <dir> <tool>` — `zellij action new-pane --cwd <dir> --stacked
  -- zsh -c '<tool>; exec zsh -i'` (drops to a shell when the tool exits),
  then renames the tab.
- `update_tab_indexes.sh` — renumber tabs after a structural change.

**The Zellij keybind model** (`config.kdl`): `clear-defaults=true`,
`default_mode "locked"`, every bind is `Alt <key>` and ends with
`SwitchToMode "locked"`. Shell-outs use:

```kdl
bind "Alt <k>" { Run "zsh" "-c" "$HOME/.../script.sh" { close_on_exit true; in_place true; }; SwitchToMode "locked"; }
```

---

## Migration mapping

The toggleterm registry's `get_or_create(name, {cmd})` maps almost 1:1 onto a
Zellij named pane. The translation table:

| Toggleterm concept | Zellij equivalent |
|--------------------|-------------------|
| `registry.get_or_create('make-start', {cmd='make start'})` | `zellij action new-pane --name make-start --cwd <dir> -- zsh -c 'make start'` |
| Terminal name (slugified cmd) | Pane name (`--name`) — reuse for "focus if exists" |
| `close_on_exit = false` (default) | omit `--close-on-exit`; wrap cmd so shell stays: `-- zsh -ic '<cmd>; exec zsh'` |
| `direction = 'horizontal'` (size 15) | `new-pane --direction down` (or `--stacked`) |
| `tf` terminal picker | `zellij action` has no native picker → keep an fzf launcher over `list panes` (see below) |
| `tx` kill all | iterate panes / close-all-but-focus, or a tagged-tab teardown |
| `nvim-toggleterm-read` skill | `zellij action dump-screen <file>` per named pane (new tiny skill) |

### Key behavioural decisions to preserve

1. **Named reuse.** Toggleterm focuses an existing live terminal instead of
   spawning a duplicate. Zellij `new-pane --name X` does *not* dedupe — it always
   creates. To replicate, a launcher must check existing pane names first
   (`zellij action dump-layout` → grep `name="X"`) and `go-to`/focus instead of
   re-spawning. **This is the main piece of logic to port.**
2. **Stay open on exit.** Toggleterm keeps output after exit. In Zellij, run the
   command via `zsh -ic '<cmd>; echo; read -k1'` (or `exec zsh`) so the pane
   doesn't vanish — do **not** pass `--close-on-exit`.
3. **Working directory.** Toggleterm inherits nvim's cwd. Zellij launchers should
   reuse `current_pane_dir` (already battle-tested in `open_ai_chat.sh`).

---

## Proposed architecture

Mirror the existing zellij launcher pattern. Add one runner script plus a small
shared helper, and bind it to a new `Alt` key.

```
etc/scripts/src/zellij/
├── run_command.sh        # NEW: named-pane "get_or_create" + run a command
├── run_npm_script.sh     # NEW: fzf over package.json scripts → run_command
├── run_make_target.sh    # NEW: fzf over Makefile targets → run_command
└── run_maven.sh          # NEW: maven actions (package/test/file/coverage)

etc/scripts/utils/utility.sh
└── run_named_pane()      # NEW shared helper: dedupe-by-name, focus-or-spawn
```

### The core helper (port of `get_or_create`)

```bash
# run_named_pane <name> <dir> <cmd>
# Focus an existing live pane with this name, else spawn one running <cmd>.
# Keeps the pane open after the command exits (toggleterm parity).
run_named_pane() {
    local name="$1" dir="$2" cmd="$3"
    [[ -n "${ZELLIJ:-}" ]] || return 1

    # Reuse if a pane with this name already exists in the current tab.
    if zellij action dump-layout 2>/dev/null | grep -q "name=\"$name\""; then
        zellij action go-to-pane-name "$name" 2>/dev/null && return 0
        # (fallback: zellij has limited focus-by-name; otherwise just respawn)
    fi

    zellij action new-pane --name "$name" --cwd "$dir" --direction down \
        -- zsh -ic "$cmd; echo; echo '[exited — press any key]'; read -k1"
}
```

> Note: focus-by-name support varies by Zellij version. Verify
> `zellij action --help` for `go-to-pane-name` / `move-focus` options; if absent,
> fall back to always-spawn or a focused-pane search. This is the one spot that
> needs a version check during implementation.

### Example runner: npm script (`<leader>tnj` equivalent)

```bash
#!/bin/bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../utils/logging.sh"
source "$SCRIPT_DIR/../../utils/utility.sh"

main() {
    [[ -z "$ZELLIJ" ]] && exit 0
    require_tool fzf || exit 1

    local dir; dir="$(current_pane_dir)" || dir="$(last_project_dir)" || exit 0
    local script
    script="$(jq -r '.scripts | keys[]' "$dir/package.json" | fzf --prompt='npm run ')" || exit 0
    [[ -z "$script" ]] && exit 0

    run_named_pane "npm-$script" "$dir" "npm run $script"
    "$SCRIPT_DIR/update_tab_indexes.sh"
}
main "$@"
```

### Bind it (config.kdl)

```kdl
bind "Alt t" { Run "zsh" "-c" "$HOME/Programming/JimmyTranDev/dotfiles/etc/scripts/src/zellij/run_npm_script.sh" { close_on_exit true; in_place true; }; SwitchToMode "locked"; }
```

Follow the `zellij-config` skill when editing `config.kdl` and the
`dotfiles-shell-scripts` skill for launcher bodies.

---

## Replacing `nvim-toggleterm-read`

Once jobs run in real Zellij panes, the RPC reader becomes a thin Zellij wrapper:

```bash
# zellij-pane-read <pane-name>  → dump that pane's scrollback to stdout
zellij action dump-screen --full /tmp/zj-dump && cat /tmp/zj-dump
```

Replace the skill with one that lists named panes (`dump-layout`) and dumps a
chosen pane's screen. This is simpler than the multi-socket nvim RPC discovery
the current skill performs.

---

## Suggested rollout (incremental)

1. **Helper first.** Add `run_named_pane` to `utility.sh` with a unit test in
   `etc/scripts/tests/` (mirror `test_select_project_recency.zsh`). Verify
   dedupe/focus behaviour against the installed Zellij version.
2. **One runner.** Port `make start` (`<leader>tms`) — the simplest fixed
   command — to `run_command.sh` + an `Alt` bind. Validate end-to-end.
3. **Interactive runners.** Add npm-script and Makefile-target pickers.
4. **Maven suite.** Port `tvs/tvp/tvt/tvf/tvc/tvn/tvN/tvb` (these are just fixed
   command strings → `run_named_pane`). The file-scoped one (`tvf`) needs the
   current Java filename — pass it from nvim or resolve from the focused buffer.
5. **Reader.** Replace `nvim-toggleterm-read` with the `dump-screen` wrapper.
6. **Deprecate.** Once parity is confirmed, thin out `toggleterm.lua` keybinds
   (keep `tt`/`tf` for quick in-editor shells if still wanted) and follow the
   `deprecation-and-migration` skill to retire `terminal_registry.lua`.

## Open questions / decisions for implementer

- **Editor-context runners** (`tvf` test-current-file, `tnf` fms:types): these
  need nvim's current file/buffer. Either keep a thin nvim keybind that shells
  out to Zellij (`zellij action new-pane …`) passing the filename, or accept
  losing file-context for the pure-Zellij path.
- **Multi-select parallel scripts** (`tnm`, ≤6 parallel): Zellij can spawn N
  named panes in a loop; decide on layout (stacked vs tiled) and a teardown bind
  (`tnM` equivalent).
- **Focus-by-name** depends on the Zellij version — confirm before relying on it.
