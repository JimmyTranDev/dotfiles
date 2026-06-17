# Neovim Plugin Consolidation — Prefer snacks.nvim, fall back to mini.nvim

## TL;DR

- Consolidate 6 standalone Neovim plugins into `snacks.nvim` and `mini.nvim` modules, plus add `mini.pairs` for currently-absent autopairs.
- Guiding rule: **snacks first, mini as fallback** for features snacks does not cover.
- **High-confidence drop-ins only** (per scope decision): `nvim-surround`→`mini.surround`, `inc-rename`+`live-command`→`Snacks.rename`, `hop`+`leap`→`mini.jump`+`mini.jump2d`, `nvim-colorizer`→`mini.hipatterns`, plus new `mini.pairs`.
- Net result: **remove 6 plugins** (surround, inc-rename, live-command, hop, leap, colorizer), **add 1** (mini.pairs); mini submodules reuse the already-installed `echasnovski/mini.nvim`.
- Estimated effort: **small–medium** (8 file tasks, mostly delete + small config). Two behavior-tradeoff caveats to confirm (live rename preview, leap-vs-jump2d feel).

## Overview

The config already depends on `snacks.nvim` (picker, dashboard, indent, scope, input, notifier, lazygit, bigfile, quickfile) and `mini.nvim` (pulled by `blink.lua` for `mini.icons`, and `mini.ai` standalone). This spec replaces several single-purpose plugins with modules from those two libraries to reduce the plugin count and unify maintenance, following the rule **prefer snacks.nvim > mini.nvim** — use a snacks module where one exists, otherwise use mini.

Reference upstreams:
- snacks.nvim: https://github.com/folke/snacks.nvim
- mini.nvim: https://github.com/nvim-mini/mini.nvim
- mini.pairs: https://github.com/nvim-mini/mini.pairs

## Architecture

All changes live under `src/nvim/lua/plugins/` (lazy.nvim plugin specs, auto-discovered by `core/lazy.lua`). No core wiring changes are required:

- `mini.nvim` is already installed (a dependency of `blink.lua`). New mini submodules (`mini.surround`, `mini.jump`, `mini.jump2d`, `mini.hipatterns`, `mini.pairs`) can be set up either as new spec files requiring `echasnovski/mini.nvim`, or `mini.pairs` standalone via `nvim-mini/mini.pairs`. Match the existing convention used by `mini-ai.lua` (standalone `echasnovski/mini.ai`).
- `Snacks.rename` lives inside the existing `snacks.lua` opts/keys — the LSP rename keymaps (`gn`, `gN`) move there alongside the other `g*` LSP keymaps already defined in `snacks.lua`.
- Deleted plugin spec files are removed from disk; lazy.nvim picks up the change on next sync. `lazy-lock.json` entries for removed plugins should be pruned via `:Lazy clean`.

Layer map:
| Concern | Today | After |
|---|---|---|
| Surround text objects | `plugins/surround.lua` (nvim-surround) | `plugins/mini-surround.lua` (mini.surround) |
| LSP rename | `plugins/inc-rename.lua` + `plugins/live-command.lua` | `Snacks.rename` keys in `plugins/snacks.lua` |
| f/F/t/T motion | `plugins/hop.lua` (hop.nvim) | `plugins/mini-jump.lua` (mini.jump) |
| s/S 2-char jump | `plugins/leap.lua` (leap.nvim) | `plugins/mini-jump2d.lua` (mini.jump2d) |
| Color-code highlighting | `plugins/colorizer.lua` (nvim-colorizer) | `plugins/mini-hipatterns.lua` (mini.hipatterns) |
| Autopairs | _none (blink auto_brackets disabled)_ | `plugins/mini-pairs.lua` (mini.pairs) — **new feature** |

## Data flow

Editor startup → `core/lazy.lua` discovers specs in `plugins/` → lazy.nvim loads each spec on its trigger:
1. `mini.surround` — loaded on `InsertEnter`/keys, registers `sa`/`sd`/`sr` operators (or custom mappings to match nvim-surround's defaults).
2. `Snacks.rename` — invoked on `gn`/`gN` keypress; calls `vim.lsp.buf.rename` with a snacks input UI, applies workspace edits via LSP.
3. `mini.jump` — overrides `f`/`F`/`t`/`T` with smarter, repeatable single-char jumps (line-local to match current hop behavior).
4. `mini.jump2d` — `s`/`S` triggers 2D labeled jump across visible buffer/window.
5. `mini.hipatterns` — on buffer attach, scans for hex/`rgb()` color tokens and applies inline highlight groups.
6. `mini.pairs` — on `InsertEnter`, auto-inserts/deletes matching brackets and quotes as you type.

## Tasks

1. **`plugins/mini-surround.lua`** (new, `echasnovski/mini.surround`) — replace `nvim-surround`. **Decision: remap off `s`** (mini.jump2d owns `s`/`S`) — use a `gs*` prefix (e.g. `gsa`/`gsd`/`gsr`). Complexity: **small**. Parallel-safe.
2. **`plugins/surround.lua`** (delete) — remove after task 1 lands. Complexity: **small**. Depends on task 1.
3. **`plugins/snacks.lua`** (modify) — add `gn`/`gN` keymaps invoking **`vim.lsp.buf.rename`** (LSP symbol rename, Decision below). The snacks input UI (`input = { enabled = true }`, already on) provides the prompt. `gn` pre-fills `<cword>`; `gN` opens an empty rename prompt. Place keys next to the existing `g*` LSP block (`snacks.lua:313-372`). Complexity: **medium**. Parallel-safe.
4. **`plugins/inc-rename.lua`** (delete) — remove after task 3 lands. Complexity: **small**. Depends on task 3.
5. **`plugins/live-command.lua`** (delete) — **Decision: remove.** The only configured command is `:Norm`, not relied on elsewhere. Complexity: **small**. Parallel-safe.
6. **`plugins/mini-jump.lua`** (new, `echasnovski/mini.jump`) + **`plugins/hop.lua`** (delete) — `mini.jump` natively enhances `f`/`F`/`t`/`T` (repeatable, configurable). Port `case_insensitive = false`. **Decision: allow multi-line jumps (mini default)** — do not restrict to current line. Complexity: **small**. Parallel-safe; delete after new spec verified.
7. **`plugins/mini-jump2d.lua`** (new, `echasnovski/mini.jump2d`) + **`plugins/leap.lua`** (delete) — `mini.jump2d` owns `s`/`S` (Decision below). Drops the `tpope/vim-repeat` dependency that leap pulled. Complexity: **small**. Parallel-safe; delete after new spec verified.
8. **`plugins/mini-hipatterns.lua`** (new, `echasnovski/mini.hipatterns`) + **`plugins/colorizer.lua`** (delete) — **Decision: full nvim-colorizer parity.** Configure highlighters for hex (`hipatterns.gen_highlighter.hex_color()`) plus explicit patterns for `rgb()`/`hsl()` and named CSS colors. Complexity: **medium**. Parallel-safe; delete after new spec verified.
9. **`plugins/mini-pairs.lua`** (new, `echasnovski/mini.pairs`) — **net-new autopairs**. **Decision: use `echasnovski/mini.pairs` standalone** to match the `mini-ai.lua` convention. Verify no conflict with `windwp/nvim-ts-autotag` (tag closing) or blink completion (`auto_brackets` already disabled, so no overlap). Complexity: **small**. Parallel-safe.
10. **`lazy-lock.json`** (modify) — run `:Lazy sync` / `:Lazy clean` to prune removed entries (hop.nvim, leap.nvim, nvim-surround, inc-rename.nvim, live-command.nvim, nvim-colorizer.lua, vim-repeat) and add new ones. Complexity: **small**. Sequential — after all spec files land.

All "new" tasks (1, 3, 6-new, 7-new, 8-new, 9) are parallel-safe. Each corresponding delete (2, 4, 5, 6-del, 7-del, 8-del) is sequential after its new counterpart is verified. Task 10 is last.

## API contracts

- **mini.surround setup** — **Decision: remap off the `s` key** (mini.jump2d owns `s`/`S`). Use a non-conflicting prefix, e.g. `require('mini.surround').setup({ mappings = { add = 'gsa', delete = 'gsd', replace = 'gsr', find = 'gsf', find_left = 'gsF', highlight = 'gsh', update_n_lines = 'gsn' } })`. Confirm the chosen prefix does not clash with existing `g*` LSP mappings in `snacks.lua`.
- **Symbol rename** — **Decision: LSP symbol rename.** `{ 'gn', function() vim.lsp.buf.rename(vim.fn.expand('<cword>')) end }` and `{ 'gN', function() vim.lsp.buf.rename() end }`. Snacks input provides the prompt UI via `input = { enabled = true }` (already on).
- **mini.jump** — `require('mini.jump').setup({ mappings = { forward = 'f', backward = 'F', forward_till = 't', backward_till = 'T' } })`. Multi-line jumps allowed (no `current_line_only` restriction).
- **mini.jump2d** — `require('mini.jump2d').setup({ mappings = { start_jumping = 's' } })` plus a manual `S` mapping for from-window if desired. **Owns the `s` key.**
- **mini.hipatterns** — full parity: `hex_color = hipatterns.gen_highlighter.hex_color()` plus custom highlighters for `rgb()`/`hsl()` and named CSS colors.
- **mini.pairs** — `require('mini.pairs').setup()` (defaults cover `()`/`[]`/`{}`/`""`/`''`/`` `` ``).

## State changes

- No database/config/env changes.
- `lazy-lock.json` gains/loses plugin pins.
- New plugin spec files added under `src/nvim/lua/plugins/`; six existing spec files deleted.
- New runtime feature: autopairs (mini.pairs) — changes insert-mode typing behavior globally.

## Edge cases

- **`s`/`S` key ownership** — **Resolved:** mini.jump2d owns `s`/`S`; mini.surround is remapped to a `gs*` prefix. Verify `gs*` does not shadow existing `g*` LSP mappings in `snacks.lua`.
- **mini.jump multi-line** — jumps now span multiple lines (no `current_line_only`); a behavior change from hop's line-local jumps.
- **mini.hipatterns color coverage** — named CSS colors / `rgb()` / `hsl()` / Tailwind classes that nvim-colorizer handled out of the box require explicit highlighters in mini.hipatterns.
- **mini.pairs + nvim-ts-autotag** — both manipulate insert-mode pairs/tags; verify no double-insertion in `html`/`tsx`/`jsx`.
- **mini.pairs + blink.cmp** — blink `auto_brackets` is disabled (`blink.lua:36`), so no conflict expected; verify `<CR>` confirm behavior in completion menus.
- **Live rename preview loss** — `inc-rename` shows incremental in-buffer preview of the rename; `vim.lsp.buf.rename`/`Snacks` input does not. Functional but a UX downgrade.
- **`mini.ai` vs `mini.surround`** — both are mini text-object modules; ensure no `setup()` ordering issue (independent modules, should be fine).

## Testing approach

Manual verification in Neovim (no automated test harness for this config):
- Surround: `saiw"` add, `sd"` delete, `sr"'` replace on a word.
- Rename: `gn` over a symbol with an active LSP; confirm workspace-wide rename applies.
- Motion: `fx`/`tx`/`F`/`T` jump correctly and repeat with `;`/`,`; `s` triggers 2D jump.
- Colors: open a file with `#aabbcc` and confirm inline highlight.
- Pairs: type `(`, `[`, `"` and confirm auto-close; backspace deletes the pair; test in a `.tsx` file alongside ts-autotag.
- Startup: `:Lazy` shows no errors; `:checkhealth mini` and `:checkhealth snacks` clean.

## Decisions & open questions

### Requirements
- **Decision:** `gn`/`gN` map to LSP **symbol** rename (`vim.lsp.buf.rename`), matching current inc-rename behavior.
- **Decision:** Losing `inc-rename`'s live in-buffer preview is **accepted** — proceed with `vim.lsp.buf.rename` + snacks input.
- **Decision:** `live-command.nvim` (`:Norm` preview) is **removed**; not relied on elsewhere.

### Architecture
- **Decision:** mini.jump allows **multi-line** jumps (mini default) — drop the current hop `current_line_only` restriction.
- **Decision:** mini.jump2d **replaces leap** on `s`/`S` (labeled-spot model accepted).

### Scope
- **Confirmed out of scope:** `gitsigns`→`mini.diff`, `lualine`→`mini.statusline`, `which-key`→`mini.clue`, `toggleterm`→`Snacks.terminal`, `smear-cursor`→`mini.animate`, `substitute`→`mini.operators`.

### Conventions
- **Decision:** New mini submodules installed as standalone `echasnovski/mini.X` specs (one file per module, matching `mini-ai.lua`).
- **Decision:** mini.pairs uses `echasnovski/mini.pairs` (standalone, matches existing mini convention).

### Risks
- **Resolved:** `s`/`S` key ownership → **mini.jump2d wins**; mini.surround is remapped to a non-`s` prefix (e.g. `gs*`).
- mini.pairs changes global insert-mode typing — highest behavior-change risk; verify against ts-autotag in JSX/TSX.
- Pruning `lazy-lock.json` affects reproducibility; commit the lock change together with spec deletions.
- mini.hipatterns full-parity highlighters (named CSS colors / `rgb()` / `hsl()`) require explicit pattern config — verify coverage matches prior nvim-colorizer output.

## References

- snacks.nvim — https://github.com/folke/snacks.nvim
- mini.nvim — https://github.com/nvim-mini/mini.nvim
- mini.pairs — https://github.com/nvim-mini/mini.pairs
