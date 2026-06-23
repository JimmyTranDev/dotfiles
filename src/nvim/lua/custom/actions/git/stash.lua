local registry = require('custom.utils.terminal_registry')
local util = require('custom.actions.git.util')

local M = {}

function M.reset_to_reflog()
  local reflog_output = vim.fn.system('git reflog --oneline -n 20')
  if vim.v.shell_error ~= 0 or not reflog_output or reflog_output == '' then
    vim.notify('No reflog entries found.')
    return
  end

  local reflog_entries = {}
  local reflog_hashes = {}

  for line in reflog_output:gmatch('[^\n]+') do
    if line ~= '' then
      local hash = line:match('^(%S+)')
      if hash then
        table.insert(reflog_entries, line)
        reflog_hashes[line] = hash
      end
    end
  end

  if #reflog_entries == 0 then
    vim.notify('No reflog entries to display.')
    return
  end

  vim.ui.select(reflog_entries, {
    prompt = 'Select reflog entry to reset to:',
    format_item = function(item) return item end,
  }, function(selected_entry)
    if not selected_entry then return end

    local hash = reflog_hashes[selected_entry]
    if not hash then
      vim.notify('Failed to extract hash from reflog entry')
      return
    end

    local reset_options = {
      'soft (keep changes staged)',
      'mixed (keep changes unstaged)',
      'hard (discard all changes)',
    }

    vim.ui.select(reset_options, {
      prompt = 'Select reset type:',
    }, function(reset_type)
      if not reset_type then return end

      local reset_flag = ''
      if reset_type:match('^soft') then
        reset_flag = '--soft'
      elseif reset_type:match('^mixed') then
        reset_flag = '--mixed'
      elseif reset_type:match('^hard') then
        reset_flag = '--hard'
      end

      local cmd = string.format('git reset %s %s', reset_flag, hash)
      vim.cmd(string.format("TermExec5 cmd='%s'", cmd))

      vim.notify(string.format('Reset %s to %s', reset_flag, hash))
    end)
  end)
end

local function stash_with_flags(extra_flags, success_msg)
  vim.ui.input({
    prompt = 'Stash message (optional): ',
  }, function(message)
    local cmd
    if message and message ~= '' then
      cmd = string.format('git stash push%s -m "%s"', extra_flags, util.shell_escape_message(message))
    else
      cmd = 'git stash' .. extra_flags
    end

    vim.cmd(string.format("TermExec5 cmd='%s'", cmd))
    vim.notify(success_msg)
  end)
end

-- Stash local changes (if any), pull with rebase, then re-apply the stash.
-- The porcelain check avoids popping an unrelated existing stash when the
-- working tree is clean (git stash exits 0 without creating a stash).
function M.stash_pull_rebase()
  local cmd =
    [==[if [ -n "$(git status --porcelain)" ]; then git stash push -m "nvim stash-pull" && git pull --rebase && git stash pop; else git pull --rebase; fi]==]
  registry.get_or_create('stash-pull', { cmd = cmd })
end

-- Clear (refresh) the local develop branch from origin without leaving the
-- branch you are currently on. Stashes local changes first when the tree is
-- dirty, then fast-forwards the local develop ref to origin/develop via a
-- refspec fetch (the canonical way to update a branch you don't have checked
-- out). The stash is left in place -- those changes belong to the current
-- branch, not develop, so restore them with `git stash pop` when ready.
function M.clear_develop_branch()
  local cmd =
    [==[if [ -n "$(git status --porcelain)" ]; then git stash push -m "nvim clear-develop"; fi && git fetch origin develop:develop]==]
  registry.get_or_create('clear-develop', { cmd = cmd })
end

function M.stash_all_changes() stash_with_flags('', 'Changes stashed successfully') end

function M.stash_keep_changes() stash_with_flags(' --keep-index', 'Changes stashed (keeping staged changes)') end

function M.select_and_pop_stash()
  local stash_output = vim.fn.system('git stash list')
  if vim.v.shell_error ~= 0 or not stash_output or stash_output == '' then
    vim.notify('No stashes found.')
    return
  end

  local stash_entries = {}
  local stash_ids = {}

  for line in stash_output:gmatch('[^\n]+') do
    if line ~= '' then
      local stash_id = line:match('^(stash@{%d+})')
      if stash_id then
        table.insert(stash_entries, line)
        stash_ids[line] = stash_id
      end
    end
  end

  if #stash_entries == 0 then
    vim.notify('No stash entries to display.')
    return
  end

  vim.ui.select(stash_entries, {
    prompt = 'Select stash to pop:',
    format_item = function(item) return item end,
  }, function(selected_entry)
    if not selected_entry then return end

    local stash_id = stash_ids[selected_entry]
    if not stash_id then
      vim.notify('Failed to extract stash ID from entry')
      return
    end

    local cmd = string.format('git stash pop %s', stash_id)
    vim.cmd(string.format("TermExec5 cmd='%s'", cmd))

    vim.notify(string.format('Popped stash %s', stash_id))
  end)
end

function M.git_add_patch(extra_args)
  return function()
    local status = vim.fn.system('git status --porcelain')
    if status == '' or status == nil then
      vim.notify('Nothing to add - working tree clean', vim.log.levels.INFO, { title = 'Git' })
      return
    end

    local has_unstaged = false
    for line in status:gmatch('[^\r\n]+') do
      if line:match('^.[MD]') or line:match('^??') then
        has_unstaged = true
        break
      end
    end

    if not has_unstaged then
      vim.notify('No unstaged changes to add', vim.log.levels.INFO, { title = 'Git' })
      return
    end

    local args = extra_args and extra_args ~= '' and (' ' .. extra_args) or ''
    vim.cmd('tabnew')
    vim.cmd(string.format('terminal git add -N . && git add -p%s; exit', args))
    vim.cmd('startinsert')

    local term_win = vim.api.nvim_get_current_win()
    local term_buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_create_autocmd('TermClose', {
      buffer = term_buf,
      once = true,
      callback = function()
        if vim.api.nvim_win_is_valid(term_win) then vim.api.nvim_win_close(term_win, true) end
      end,
    })
  end
end

function M.reset_all_with_confirm()
  local status = vim.fn.system('git status --porcelain')
  if status == '' or status == nil then
    vim.notify('Nothing to reset - working tree clean', vim.log.levels.INFO, { title = 'Git' })
    return
  end

  local changes_count = 0
  for _ in status:gmatch('[^\r\n]+') do
    changes_count = changes_count + 1
  end

  vim.ui.input({
    prompt = string.format(
      'Reset ALL changes? This will:\n- Reset staged files\n- Clean untracked files\n- Restore modified files\n\nAffected files: %d\nType "y" to confirm: ',
      changes_count
    ),
  }, function(confirmation)
    if confirmation ~= 'y' then
      vim.notify('Reset cancelled.')
      return
    end

    vim.cmd("TermExec5 open=0 cmd='git reset .'")
    vim.cmd("TermExec5 open=0 cmd='git clean -df'")
    vim.cmd("TermExec5 open=0 cmd='git restore .'")
    vim.notify(string.format('Reset ALL changes (%d files affected)', changes_count))
  end)
end

return M
