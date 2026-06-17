---
todoist:
  - https://app.todoist.com/app/task/create-copy-programming-git-repo-dir-keymap-select-6gv2gpm6Gjw7v3pm
  - https://app.todoist.com/app/task/add-a-pull-and-copy-repo-dir-keymap-nvim-6gvF4R7cQm92J72F
  - https://app.todoist.com/app/task/create-description-add-too-for-the-add-jira-task-6gv48QJGC536QWrF
  - https://app.todoist.com/app/task/add-command-to-save-to-notes-6gvCgHjHwJpc4VjF
  - https://app.todoist.com/app/task/create-keymap-to-search-work-notes-6gvChxHwcm3HG6RF
  - https://app.todoist.com/app/task/add-work-note-adding-keymap-6gvCj26fJJjjRhqF
  - https://app.todoist.com/app/task/add-opencode-like-file-autocoplete-to-add-todoist-task-6gvCqVvF5Gr9vH8F
  - https://app.todoist.com/app/task/group-the-leaderr-keymaps-6gvFhV6rRG3PMW5m
  - https://app.todoist.com/app/task/reverse-the-leaderult-and-ult-keymaps-in-nvim-6gvFp7gxGXP9g8wm
  - https://app.todoist.com/app/task/improve-the-mnemnoics-of-the-keymaps-nvim-6gvFm84WpF8mpc4m
  - https://app.todoist.com/app/task/check-that-the-edit-todoist-and-jira-keymaps-work-6gvFhW6qJg4cf94m
---

# Devtools: Neovim Keymaps & Capture Actions

## TL;DR
- Covers 11 p1 tasks refining the nvim keymap layer: copy-repo-dir consolidation, Jira description prompt, work-notes capture/search, Todoist file autocomplete, `<leader>r` grouping, an `ult`/`ulT` swap, mnemonic cleanup, and a verification pass.
- All changes live in `src/nvim/lua/core/keymaps.lua`, `src/nvim/lua/custom/actions/*.lua`, and `src/nvim/lua/plugins/which-key.lua`.
- Most critical / highest-leverage: consolidating the repo-dir copy keymaps (avoids duplicating `<leader>cr`/`<leader>cR`) and the work-notes capture trio (new daily-driver workflow).
- Estimated effort: ~1 medium day. Mostly Small tasks; the Todoist file autocomplete and work-notes search are Medium.
- 3 tasks are pure refactors/verification (grouping, mnemonics, edit-keymap check) with no new behavior.

## Overview
This spec hardens the Neovim capture/navigation keymap layer. It consolidates duplicate repo-path copy actions, adds a description step to Jira task creation, introduces a "work notes" capture+search workflow on top of the existing notes store, adds opencode-style file-path autocomplete to the Todoist task logger, and tidies the `<leader>r` group and mnemonics. It touches only the dotfiles `src/nvim` tree.

## Architecture
- **Keymap registry**: `src/nvim/lua/core/keymaps.lua` is the single place where `map(...)` calls and the `<leader>c`/`<leader>r`/`<leader>ul` groups are wired (see keymaps.lua:94-145, 193-197).
- **Action modules**: `src/nvim/lua/custom/actions/*.lua` hold the implementations. Relevant: `notes.lua` (NOTES_PATH = `~/Programming/JimmyTranDev/notes/people`, SENTENCES_PATH = `~/notes/notes`, TASKS_FILE = `~/notes/tasks.md`), `jira.lua` (`create_task_handler` at jira.lua:386), `todoist.lua` (`log_todoist_task_all_projects` at todoist.lua:266), `files.lua` (`copy_repo_path` at files.lua:187), `project.lua` (`copy_project_path` at project.lua:94).
- **which-key labels**: `src/nvim/lua/plugins/which-key.lua` defines group descriptions (e.g. `<leader>r` = "Capture & Log" at which-key.lua:117).

## Data flow
1. User presses a `<leader>` sequence → `keymaps.lua` dispatches to an action function.
2. Action prompts via `vim.ui.select` / `vim.ui.input` (or Snacks picker), reads/writes a markdown file under `~/Programming/JimmyTranDev/notes`, or copies a string to the `+` register.
3. Notes writes call `git_utils.sync_notes_repo()` to commit/push the notes repo.

## Tasks
| # | File | Change | Complexity | Deps | Parallel? |
|---|------|--------|------------|------|-----------|
| 1 | `src/nvim/lua/custom/actions/files.lua` + `project.lua` | Consolidate repo-dir copy: make `copy_repo_path` (current repo) and `copy_project_path` (pick) the canonical actions. Add a "pick repo from programming dir then copy path" if not already covered, and a "pull (clone/fetch) repo then copy dir" variant. Avoid adding net-new near-duplicates of `<leader>cr`/`<leader>cR`. | Medium | None | Yes |
| 2 | `src/nvim/lua/core/keymaps.lua` | Wire the consolidated copy actions; remove/redirect any duplicate bindings | Small | 1 | Sequential after 1 |
| 3 | `src/nvim/lua/custom/actions/jira.lua` | Add an optional description `vim.ui.input` step inside `create_task_handler` (jira.lua:386) so `create_jira_task` sends a description to `acli` | Small | None | Yes |
| 4 | `src/nvim/lua/custom/actions/notes.lua` | Add `save_to_notes` command/action (general capture to notes store) | Small | None | Yes |
| 5 | `src/nvim/lua/custom/actions/notes.lua` | Add `add_work_note` — pick a topic file from a `notes/work/` dir (or create new), append entry; mirror the `add_notes_entry` picker pattern | Small | None | Yes |
| 6 | `src/nvim/lua/custom/actions/notes.lua` | Add `search_work_notes` (grep/picker over `notes/work/*.md` via Snacks) | Medium | 5 | Sequential after 5 |
| 7 | `src/nvim/lua/custom/actions/todoist.lua` | Add opencode-style file-path autocomplete inside the `log_todoist_task` input so a file reference can be embedded in the task text | Medium | None | Yes |
| 8 | `src/nvim/lua/core/keymaps.lua` | Group all `<leader>r...` keymaps contiguously and consistently (keymaps.lua:134-145) | Small | 3,4,5,6 | Sequential |
| 9 | `src/nvim/lua/core/keymaps.lua` | Reverse `<leader>ult` (currently repo) and `<leader>ulT` (currently select) so the more-used action is on lowercase (keymaps.lua:196-197) | Small | None | Yes |
| 10 | `src/nvim/lua/core/keymaps.lua` + `which-key.lua` | Improve mnemonics across keymaps (align letters to action meaning; update which-key descriptions) | Medium | 8,9 | Sequential |
| 11 | n/a (verification) | Manually verify `edit_recent_task` (`<leader>rT`) and Jira edit keymaps work end-to-end; fix if broken | Small | 3 | Sequential |

## API contracts
- `notes.add_work_note()` / `notes.search_work_notes()` / `notes.save_to_notes()` — zero-arg Lua functions returning nil, following the existing `notes.lua` action signature style.
- Jira description: `create_jira_task` must pass the description through to the existing `acli jira workitem create` invocation (add a `--description` arg or body field).

## State changes
- New `~/Programming/JimmyTranDev/notes/work/` directory with per-topic markdown files for work notes (selected/created via picker). No DB or config schema changes.
- No new plugins.

## Edge cases
- Empty input on any `vim.ui.input` → abort silently (match existing pattern, e.g. notes.lua:46).
- Work-notes file does not exist yet → create it on first add.
- Jira description left blank → send no description (don't send empty string).
- Todoist autocomplete with no file match → fall back to plain text entry.
- `copy_repo_path` outside a git repo → notify and abort.

## Testing approach
- Manual: trigger each keymap, confirm file writes land in the right path and the notes repo syncs.
- Verify `+` register contents for copy actions.
- Task 11 is itself the verification gate for the edit keymaps.

## Open questions
### Requirements
- **Decision: Work notes live in a per-topic `~/Programming/JimmyTranDev/notes/work/` directory** (one `.md` file per topic, selected/created via picker — mirrors `add_notes_entry`).
- **What does "save to notes" (#19) capture?** Current buffer selection, a prompted sentence, or the current file reference? (Recommend: prompted sentence appended to a daily/quick notes file, mirroring `quick_note`.) — Decision pending.

### Conventions
- **#10 copy "select" vs #26 "pull and copy"** — confirm #26 means clone-if-missing-then-copy-path vs fetch-latest-then-copy. (Recommend: clone if missing, else `git pull`, then copy dir path.) — Decision pending.
