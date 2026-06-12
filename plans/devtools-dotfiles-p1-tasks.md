---
todoist: https://app.todoist.com/app/project/dotfiles-6gr5JcW79WCMG37F
---

# Dotfiles P1 Tasks

## TL;DR

- 12 tasks across nvim keymaps/plugins, scripts, zellij integration, and opencode plugin
- 1 bug fix (`<leader>rt` back option infinite loop), 3 cleanup/rename tasks, 4 new features, 4 enhancements
- Critical path: most tasks are independent and can be worked in parallel
- Estimated effort: ~2-3 days total, mostly small/medium complexity
- 1 task already completed and marked done (copilot reenable)

## Overview

This spec covers 12 p1 priority tasks from the dotfiles Todoist project. The tasks span four areas: nvim configuration (keymaps, plugins, cleanup), shell scripts (pnpm migration, worktree enhancements), zellij integration (layouts, project switching), and the opencode notification plugin. All tasks modify the dotfiles repo at `~/Programming/JimmyTranDev/dotfiles/`.

## Architecture

All changes live within the dotfiles repo structure:

- **Nvim config** (`src/nvim/lua/`): Core keymaps at `core/keymaps.lua`, plugin specs at `plugins/*.lua`, action modules at `custom/actions/*.lua`, utility modules at `custom/utils/*.lua`
- **Shell scripts** (`etc/scripts/`): Worktree helpers at `src/worktrees/`, zshrc helpers at `src/zshrc/`, install scripts at `src/install/`, AI utility scripts at `src/ai/`
- **Zellij** (`src/zellij/`): Main config at `config.kdl`, layouts as `.kdl` files
- **OpenCode** (`src/opencode/`): Plugins at `plugins/`, config at `opencode.jsonc`
- **Shell config** (`src/.zshrc`): Aliases, keybindings, sourced helper scripts

## Data flow

Not applicable -- these are independent tooling improvements with no shared data pipeline.

## Tasks

### Group A: Nvim Bug Fixes & Cleanup

#### T1: Fix `<leader>rt` back option infinite loop

- **Todoist**: https://app.todoist.com/app/task/fix-back-option-in-leaderrt-not-working-6gr6g92H54q9WCRm
- **File**: `src/nvim/lua/custom/actions/todoist.lua`
- **What**: The `select_priority` back action (line 187) calls `select_section(selected_project)` which auto-skips back to `select_priority` when the project has 0 or 1 sections (lines 138-141, 156-159), creating an infinite loop. Fix by making the back action from `select_priority` skip `select_section` when section was auto-selected, going directly to `select_project` instead.
- **Fix approach**: In `select_priority`'s `on_back` callback (line 187), check if the section was auto-selected (0 or 1 sections). If so, call `select_project()` instead of `select_section(selected_project)`. Same fix for the `is_back` check on line 189.
- **Complexity**: Small
- **Dependencies**: None
- **Parallel**: Yes

#### T2: Remove slack nvim code

- **Todoist**: https://app.todoist.com/app/task/slack-api-and-cli-doesnt-work-remove-all-logic-related-to-slack-6gr6mvhq3vhjpCXm
- **Scope**: Only nvim code (per user clarification). Shell scripts and Brewfile are kept.
- **Files to modify/delete**:
  - **Delete** `src/nvim/lua/custom/actions/slack.lua` (48 lines) -- `post_good_morning()` action
  - **Delete** `src/nvim/lua/custom/utils/slack.lua` (56 lines) -- `get_token()`, `post_message()` utility
  - **Modify** `src/nvim/lua/core/keymaps.lua`:
    - Remove line 13: `local slack_actions = require('custom.actions.slack')`
    - Remove line 131: `map('n', '<leader>rs', slack_actions.post_good_morning, 'Post good morning')`
- **Also clean up**:
  - Remove stale `tool-slack-cli/` reference from `src/opencode/AGENTS.md` line 137 (directory doesn't exist)
- **Complexity**: Small
- **Dependencies**: None
- **Parallel**: Yes

#### T3: Improve `<leader>u` keymap naming

- **Todoist**: https://app.todoist.com/app/task/improve-the-naming-of-leaderu-keymaps-6gr6g7XrW4Q39gxm
- **File**: `src/nvim/lua/core/keymaps.lua` (lines 177-216), `src/nvim/lua/plugins/which-key.lua` (group label)
- **What**: Review all `<leader>u` keymaps and make their `desc` strings more consistent, concise, and descriptive. Current names are inconsistent (some say "Open", some say "Copy", some are vague like "Useful link").
- **Current group name** in which-key: `"URL / Open"` -- evaluate if this should change
- **Approach**: Audit all 22 `<leader>u*` keymaps, propose a consistent naming scheme (e.g., prefix pattern: `GitHub: ...`, `Jira: ...`, `Link: ...`), update `desc` strings
- **Complexity**: Small
- **Dependencies**: None
- **Parallel**: Yes

#### T4: Improve `<leader>c` keymap naming

- **Todoist**: https://app.todoist.com/app/task/improve-the-naming-of-things-in-leaderc-6gr6ggPfFWhP3M2F
- **File**: `src/nvim/lua/core/keymaps.lua` (lines 90-175), `src/nvim/lua/plugins/which-key.lua` (group label)
- **What**: Same as T3 but for the `<leader>c` group. Current names like "Copy testable Slack message" reference the now-removed Slack integration. Names should be consistent and descriptive.
- **Current group name** in which-key: `"Copy & Quick Access"` -- evaluate if this should change
- **Approach**: Audit all 12 `<leader>c*` keymaps, ensure naming consistency
- **Complexity**: Small
- **Dependencies**: T2 (slack removal may affect `<leader>c` names referencing Slack)
- **Parallel**: After T2

### Group B: Nvim New Features

#### T5: Create nvim keymap for PR diff of current branch

- **Todoist**: https://app.todoist.com/app/task/create-nvim-keymap-that-gets-a-diff-of-pr-of-current-branch-6gmxWJwPC792gj5v
- **Files**:
  - **Modify** `src/nvim/lua/custom/actions/git.lua` or create `src/nvim/lua/custom/actions/github.lua` -- add a function that fetches the PR diff for the current branch
  - **Modify** `src/nvim/lua/core/keymaps.lua` -- add keymap (likely in `<leader>u` or `<leader>j` group)
- **What**: New keymap that shows the diff of the PR associated with the current git branch. Should use `gh pr diff` or `gh pr view --json` to get the diff and display it in a Snacks picker or buffer.
- **Approach**:
  1. Get current branch: `git branch --show-current`
  2. Get PR diff: `gh pr diff` (outputs unified diff for the current branch's PR)
  3. Decision: Display as a **Snacks picker** showing changed files with diff preview (file-by-file navigation). Parse the unified diff output to extract per-file diffs, show file list in picker, preview each file's diff on selection.
  4. Handle edge case: if no PR exists for current branch, show error notification
- **Complexity**: Medium
- **Dependencies**: None
- **Parallel**: Yes

#### T6: Make snacks pickers resumable via `<leader>fr`

- **Todoist**: https://app.todoist.com/app/task/make-all-of-the-snacks-things-lastable-can-use-leaderft-to-reopen-6gpC249MFCrjpRFM
- **File**: `src/nvim/lua/plugins/snacks.lua`, various `custom/actions/*.lua` files that create custom Snacks pickers
- **What**: Currently `<leader>fr` calls `Snacks.picker.resume()` which reopens the last _built-in_ Snacks picker. Custom pickers (like `<leader>ft` FMS text lookup in `custom/actions/language.lua`) may not participate in the resume mechanism. Ensure all custom Snacks picker invocations are compatible with `Snacks.picker.resume()`.
- **Investigation needed**: Check if `Snacks.picker.resume()` already works with custom pickers created via `Snacks.picker()`. If it does, this task may already work. If not, find out what's needed to make custom pickers resumable.
- **Complexity**: Small-Medium (depends on Snacks.nvim API behavior)
- **Dependencies**: None
- **Parallel**: Yes

#### T7: Add octo.nvim plugin

- **Todoist**: https://app.todoist.com/app/task/add-octo-nvim-6gr6qqmPVvCgRpHF
- **Files**:
  - **Create** `src/nvim/lua/plugins/octo.lua` -- plugin spec for `pwntester/octo.nvim`
  - **Modify** `src/nvim/lua/plugins/which-key.lua` -- add group label for octo keymaps (likely under `<leader>gh` "GitHub" group which already exists at line 71)
- **What**: Add octo.nvim for in-editor GitHub PR review, issue browsing, and PR commenting. Configure with lazy loading (load on `:Octo` command), keymaps under `<leader>gh` namespace.
- **Key decisions**: Which octo keymaps to expose, how to integrate with existing `<leader>u` GitHub keymaps without conflicts
- **Complexity**: Medium
- **Dependencies**: None
- **Parallel**: Yes

### Group C: Scripts & Tooling

#### T8: Move fully to global pnpm instead of npm

- **Todoist**: https://app.todoist.com/app/task/move-fully-to-global-pnpm-instead-of-npm-6gmWFmj75Hx5Q9wM
- **Files to modify**:
  - `etc/scripts/src/install/common.sh` lines 67-77: Change `npm install -g eas-cli` to `pnpm add -g eas-cli`
  - Audit all scripts for any other `npm install -g` calls
- **What**: Replace any remaining `npm install -g` with `pnpm add -g`. The install script already uses `pnpm add -g` for most tools (lines 54-65) but falls back to npm for eas-cli.
- **Complexity**: Small
- **Dependencies**: None
- **Parallel**: Yes

#### T9: Allow `wn` to create worktree from existing worktrees

- **Todoist**: https://app.todoist.com/app/task/wn-script-be-able-to-create-worktree-from-other-worktrees-too-6gqqPfg3vjQPX4QM
- **Files**:
  - **Modify** `etc/scripts/src/worktrees/commands/create.sh` -- update `get_repository()` or the repo selection logic
  - **Modify** `etc/scripts/utils/worktree_core.sh` -- update `get_repository()` function if it's defined there
- **What**: Currently `wn` scans `~/Programming/*/` for git repos to create worktrees from. The user wants it to also include repos in `~/Programming/wcreated/` and `~/Programming/wcheckout/` directories. This allows creating a new worktree branching off from an existing worktree's branch.
- **Approach**:
  1. Extend the repo scanning in `get_repository()` to include `~/Programming/wcreated/*` and `~/Programming/wcheckout/*`
  2. When a worktree dir is selected, detect its parent repo and use the worktree's current branch as the base branch (instead of auto-detecting develop/main)
  3. Label worktree entries differently in fzf (e.g., `[wcreated] branch-name` vs `[project] repo-name`)
- **Complexity**: Medium
- **Dependencies**: None
- **Parallel**: Yes

### Group D: Zellij & OpenCode Integration

#### T10: Create keymap to open zellij tab with 4 opencode panes

- **Todoist**: https://app.todoist.com/app/task/create-keymap-to-open-zellij-tab-with-opencode-already-open-in-4-panes-6gr6RRrQJjxxWf2m
- **Files**:
  - **Create** `etc/scripts/src/zellij/open_opencode_quad.sh` -- script that creates a new Zellij tab with 4 panes each running `opencode`
  - **Modify** `src/zellij/config.kdl` -- add keybind (or add to `.zshrc` as an alias/function)
  - Optionally **create** `src/zellij/layouts/opencode-quad.kdl` -- Zellij layout file defining 4 panes
- **What**: A Zellij keybind in locked mode (e.g., `Alt+O`) that opens a new tab with a 2x2 grid of 4 panes, each running `opencode` in the current project directory. Decision: **Zellij keybind**, not shell function.
- **Approach**:
  1. Create a Zellij layout file (`opencode-quad.kdl`) with a 2x2 pane grid
  2. Each pane runs `opencode` as its command
  3. Script uses `zellij action new-tab --layout <path> --cwd <dir>` to launch
  4. Bind to Zellij keybind in locked mode (e.g., `Alt+O`)
- **Complexity**: Medium
- **Dependencies**: None
- **Parallel**: Yes

#### T11: Create nvim keymap to open another project in current tab

- **Todoist**: https://app.todoist.com/app/task/create-keymap-to-open-another-project-in-current-tab-6gr6Rg8f7H6jg69m
- **Files**:
  - **Modify** `src/nvim/lua/custom/actions/project.lua` -- extend `switch_project()` or add a new function
  - **Modify** `src/nvim/lua/core/keymaps.lua` -- add/update keymap
- **What**: A nvim keymap that lets the user pick a different project and switch to it in the current Zellij tab. This is like `<leader>fW` (`switch_project`) but should also update the Zellij tab name to reflect the new project. Decision: this is a **nvim keymap** (not shell).
- **Approach**:
  1. Extend the existing `switch_project()` in `custom/actions/project.lua`
  2. After `vim.cmd('cd ' .. path)`, call `vim.fn.system('zellij action rename-tab "' .. project_name .. '"')` to update the Zellij tab name
  3. The chpwd hook in the shell won't fire (since vim is managing the cd, not the shell), so the tab rename must be done explicitly from nvim
- **Complexity**: Small
- **Dependencies**: None
- **Parallel**: Yes

#### T12: OpenCode notification plugin -- use session name

- **Todoist**: https://app.todoist.com/app/task/make-the-opencode-notifiation-plugin-use-the-opencode-session-name-6gqrj7gWwfVWgH3M
- **File**: `src/opencode/plugins/notification.js`
- **What**: Replace `getProjectName()` (which reads `process.cwd()` basename) with the OpenCode session name/ID. The user wants the notification to show the OpenCode session identifier.
- **Challenge**: The current plugin API does not expose a session name/ID in event properties. The plugin receives `{ $ }` (shell executor) and `{ event }` per event, with no session context object.
- **Approach options**:
  1. Use `$` to execute `opencode session` or similar CLI command to get the session name
  2. Read the `OPENCODE_SESSION` or similar environment variable if OpenCode sets one
  3. Read the Zellij tab name via `zellij action query-tab-names` as a proxy for session identity
  4. Check OpenCode docs/source for any session info accessible to plugins
- **Complexity**: Medium (depends on what OpenCode exposes)
- **Dependencies**: None
- **Parallel**: Yes

## API contracts

No new APIs. All changes are internal to dotfiles configuration.

## State changes

- **T2**: Removes `slack.lua` action and util files from nvim config
- **T7**: Adds new `octo.lua` plugin file
- **T10**: Adds new Zellij layout file and script
- **No new environment variables** unless T12 requires reading one
- **No database or persistent state changes**

## Edge cases

- **T1 (back fix)**: Must handle all three section count cases: 0 sections, 1 section, 2+ sections. The back chain should be: priority -> section (if >1) -> project -> input, never creating loops.
- **T5 (PR diff)**: Handle case where current branch has no associated PR (show error notification). Handle case where PR is in draft or closed state.
- **T9 (wn from worktrees)**: Handle case where selected worktree's repo no longer exists. Handle case where the worktree's branch has been deleted on remote.
- **T10 (4-pane opencode)**: Handle case where opencode is not installed. Handle case where current directory is not a git repo.
- **T12 (session name)**: Fallback to `process.cwd()` basename if session name is unavailable.

## Testing approach

Manual testing for all tasks (dotfiles config changes). For each task:
- T1: Create a Todoist task in a project with 0 sections, verify back navigation works
- T2: Verify nvim starts without errors after slack code removal
- T3/T4: Verify which-key popup shows updated names
- T5: Run keymap in a repo with an open PR, verify diff displays
- T7: Run `:Octo pr list` to verify plugin loads
- T8: Run `pnpm list -g` to verify eas-cli is installed via pnpm
- T9: Run `wn` and verify wcreated/wcheckout dirs appear in fzf
- T10: Trigger keymap, verify 4-pane tab opens with opencode running
- T12: Trigger a notification, verify session name appears

## Decisions

1. **T5 PR diff format**: Decision: Snacks picker showing changed files with diff preview (file-by-file navigation).
2. **T7 octo.nvim keymaps**: Decision: Use `<leader>gh` (existing GitHub group in which-key). Expose common octo commands as keymaps, leave advanced ones as `:Octo` commands.
3. **T10 keymap location**: Decision: Zellij keybind in locked mode (e.g., `Alt+O`).
4. **T11 context**: Decision: This is a **nvim keymap**, not a shell keymap. Extends `switch_project()` with Zellij tab rename.
5. **T3/T4 naming**: Decision: Propose new names during implementation for review.
6. **T12 session name fallback**: Decision: Keep `process.cwd()` basename as fallback if OpenCode session info is unavailable.

## Open questions

None remaining -- all questions resolved during specification.
