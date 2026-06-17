# Neovim Plugin Recommendations — Gap Analysis

> Output of task #3 in `devtools-nvim-plugins.md` (recommend useful plugins based on the
> current set). This is a **report only** — install in a follow-up per the spec decision.

## Current set (summary)

`src/nvim/lua/plugins/` currently covers:

- **Completion / LSP**: blink, mason-lspconfig, typescript-tools, java (jdtls), workspace-diagnostics
- **UI / theme**: catppuccin, lualine, dropbar, snacks (picker/dashboard/notifier/input/indent/scope/lazygit), markview, smear-cursor, rainbow-csv
- **Editing**: conform (format), mini-ai, mini-surround, mini-pairs, mini-hipatterns, ts-autotag, substitute, highlight-undo
- **Motion**: hop, leap
- **Git**: fugitive, gitsigns, octo, (lazygit via snacks)
- **AI**: copilot, claudecode, opencode
- **Files / misc**: yazi, arrow, restore-file, suda, package-info, toggleterm, treesitter, which-key

## Gaps & recommendations (ranked by leverage)

| # | Plugin | Fills gap | Why it fits this config |
|---|--------|-----------|-------------------------|
| 1 | **nvim-dap** + **nvim-dap-ui** + **nvim-dap-virtual-text** | Debugging (none present) | Biggest gap. Java (jdtls) and TS dev both benefit from breakpoint debugging; jdtls integrates with `java-debug-adapter` via mason. |
| 2 | **neotest** (+ `neotest-jest`/`neotest-vitest`, `neotest-java`) | In-editor test running (none present) | Directly complements the new `uncommitted-coverage.sh` script — run/inspect tests without leaving the buffer. |
| 3 | **grug-far.nvim** | Project-wide find & replace | Answers the "Espen replace tool" task (#34): a modern, snacks-friendly search/replace UI beyond `substitute.nvim` (single-buffer) and the commented-out replacement keymaps. |
| 4 | **todo-comments.nvim** | TODO/FIXME highlight + search | Fits the capture/notes workflow; integrates with `Snacks.picker` for a TODO list across the repo. |
| 5 | **trouble.nvim** | Structured diagnostics/quickfix/LSP lists | Cleaner than raw `Snacks.picker.diagnostics` for navigating workspace diagnostics (already using workspace-diagnostics). |
| 6 | **refactoring.nvim** | Language-agnostic refactors | Extends typescript-tools' TS-only refactors to extract-function/variable across languages incl. Java. |

## Notes

- **Already covered, do not add**: harpoon (≈ `arrow.lua`), flash/leap-style motion (`hop` + `leap`), session restore (`restore-file`), git UI (`fugitive`/`gitsigns`/`octo`/snacks-lazygit), file explorer (`yazi` + snacks explorer).
- **Lowest risk first**: #4 todo-comments and #3 grug-far are self-contained and low-config; #1 dap and #2 neotest need per-language adapter wiring.
- The mini.nvim library is already installed — prefer mini submodules where one exists before adding a standalone plugin (e.g. `mini.bracketed`, `mini.move`) consistent with the snacks-first / mini-fallback rule.
