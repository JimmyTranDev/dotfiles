local async = require('custom.utils.async')
local files = require('custom.utils.files')
local input = require('custom.utils.input')
local ui = require('custom.utils.ui')

local M = {}

--- Run `git <args>` synchronously in `cwd`; return trimmed stdout, or nil on failure.
---@param cwd string
---@param args string[]
---@return string|nil
local function git_capture(cwd, args)
  local cmd = { 'git' }
  for _, a in ipairs(args) do
    cmd[#cmd + 1] = a
  end
  local res = vim.system(cmd, { text = true, cwd = cwd }):wait()
  if res.code ~= 0 then return nil end
  return (res.stdout or ''):gsub('%s+$', '')
end

local function realpath(p) return vim.uv.fs_realpath(p) or p end

local JIRA_PATTERN = '^%u+%-%d+$'

--- Strip ANSI SGR escape sequences from a string.
local function strip_ansi(s) return (s:gsub('\27%[[0-9;]*m', '')) end

--- First line of a string (up to the first CR/LF), or '' when empty.
local function first_line(s) return s:match('^[^\r\n]*') or '' end

--- Lowercase slug: non-alphanumerics collapse to a single '-', ends trimmed.
---@param text string
---@return string
function M.slugify(text)
  local s = (text or ''):lower():gsub('[^a-z0-9]', '-')
  s = s:gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
  return s
end

--- Decide a branch name from one raw input, honoring a JIRA key when given.
--- Pure: the caller fetches the JIRA summary (via acli) and passes it in.
---   - JIRA key + non-empty summary -> "<KEY>-<slug(summary)>"
---   - JIRA key + blank summary      -> "<KEY>"
---   - anything else                 -> sanitized name (case preserved)
--- Returns '' when the input sanitizes to nothing (caller should abort).
---@param input string
---@param summary string|nil
---@return string
function M.compute_branch_name(input, summary)
  input = input or ''
  if input:match(JIRA_PATTERN) then
    if summary and summary ~= '' then
      local slug = M.slugify(strip_ansi(first_line(summary)))
      return slug ~= '' and (input .. '-' .. slug) or input
    end
    return input
  end
  local s = strip_ansi(first_line(input)):gsub('[^%w._-]', '-')
  s = s:gsub('%-+', '-'):gsub('^%-', ''):gsub('%-$', '')
  return s
end

--- Build the seed commit message for a new worktree. JIRA keys get a body with
--- a browse link; plain names get a bare "<type>: <input>" subject.
---@param commit_type string
---@param input string
---@param summary string|nil
---@param org_name string|nil defaults to $ORG_NAME or 'storebrand'
---@return string
function M.build_commit_message(commit_type, input, summary, org_name)
  org_name = org_name or vim.env.ORG_NAME or 'storebrand'
  if input:match(JIRA_PATTERN) then
    local subject = (summary and summary ~= '') and (commit_type .. ': ' .. input .. ' ' .. summary) or (commit_type .. ': ' .. input)
    return subject .. '\n\nJira: https://' .. org_name .. '.atlassian.net/browse/' .. input
  end
  return commit_type .. ': ' .. input
end

--- True when `path` is a direct descendant of `wcreated_dir` (the create-side
--- container whose branches own their remote and may be deleted on cleanup).
---@param path string
---@param wcreated_dir string
---@return boolean
function M.is_wcreated_path(path, wcreated_dir)
  if not path or not wcreated_dir then return false end
  local prefix = (wcreated_dir:gsub('/+$', '')) .. '/'
  return path:sub(1, #prefix) == prefix
end

--- Sanitize free text into a git-branch-safe name (preserves case for Jira keys).
local function sanitize_branch(text)
  local s = text:gsub('%s+', '-')
  s = s:gsub('[^%w%._/-]', '-')
  s = s:gsub('%-+', '-')
  s = s:gsub('/+', '/')
  s = s:gsub('^[%-/]+', ''):gsub('[%-/]+$', '')
  return s
end

--- Derive the worktree folder name from a branch (strip a leading `segment/`).
---@param branch string
---@return string
function M.folder_from_branch(branch)
  local folder = branch:match('^[^/]+/(.+)$') or branch
  return (folder:gsub('/', '-'))
end
local folder_from_branch = M.folder_from_branch

--- Return `path`, or `path-1`, `path-2`, ... if it already exists on disk.
local function unique_path(path)
  if not vim.uv.fs_stat(path) then return path end
  local i = 1
  while vim.uv.fs_stat(path .. '-' .. i) do
    i = i + 1
  end
  return path .. '-' .. i
end

--- Re-point loaded file buffers from `old_root` to `new_root` after a folder move.
local function repoint_buffers(old_root, new_root)
  local prefix = old_root .. '/'
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:sub(1, #prefix) == prefix then
        local new_name = new_root .. '/' .. name:sub(#prefix + 1)
        pcall(vim.api.nvim_buf_set_name, buf, new_name)
        if vim.bo[buf].modified then
          vim.notify('Unsaved buffer repointed (save to new path): ' .. new_name, vim.log.levels.WARN)
        else
          vim.api.nvim_buf_call(buf, function() vim.cmd('silent! edit!') end)
        end
      end
    end
  end
end

--- Execute `steps` sequentially, aborting (with a notify) on the first failure.
--- Each step: { label, cmd (argv), before?, after? }.
local function run_sequence(steps, idx, on_done)
  idx = idx or 1
  if idx > #steps then
    if on_done then on_done() end
    return
  end

  local step = steps[idx]
  if step.before then step.before() end
  vim.notify(step.label .. '…', vim.log.levels.INFO)

  async.run_cmd(step.cmd, function(res)
    if res.code ~= 0 then
      local err = (res.stderr ~= '' and res.stderr or res.stdout):gsub('%s+$', '')
      vim.notify(step.label .. ' failed: ' .. err, vim.log.levels.ERROR)
      return
    end
    if step.after then step.after() end
    run_sequence(steps, idx + 1, on_done)
  end)
end

--- Rename the current linked worktree: its folder, local branch, and remote branch.
--- Only operates on a linked worktree (not the primary checkout) with a branch
--- checked out. The remote branch is renamed (push new + delete old) only when an
--- upstream exists and the branch name actually changes.
function M.rename_current_worktree()
  local cwd = vim.fn.getcwd()

  local toplevel = git_capture(cwd, { 'rev-parse', '--show-toplevel' })
  if not toplevel then
    vim.notify('Not inside a git worktree', vim.log.levels.ERROR)
    return
  end

  local common = git_capture(cwd, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  if not common then
    vim.notify('Could not resolve the main repository', vim.log.levels.ERROR)
    return
  end
  local main_repo = vim.fn.fnamemodify(common, ':h')

  if realpath(toplevel) == realpath(main_repo) then
    vim.notify('Refusing: this is the primary worktree, not a linked worktree', vim.log.levels.ERROR)
    return
  end

  local old_branch = git_capture(cwd, { 'rev-parse', '--abbrev-ref', 'HEAD' })
  if not old_branch or old_branch == 'HEAD' then
    vim.notify('Refusing: detached HEAD (no branch to rename)', vim.log.levels.ERROR)
    return
  end

  local upstream = git_capture(cwd, { 'rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}' })
  local remote = upstream and (upstream:match('^([^/]+)/') or 'origin')

  local old_folder = vim.fn.fnamemodify(toplevel, ':t')
  local parent = vim.fn.fnamemodify(toplevel, ':h')

  input.get_input('New worktree name: ', function(raw)
    if not raw then
      vim.notify('Rename cancelled', vim.log.levels.INFO)
      return
    end

    local new_branch = sanitize_branch(raw)
    if new_branch == '' then
      vim.notify('Invalid name', vim.log.levels.ERROR)
      return
    end

    local new_folder = folder_from_branch(new_branch)
    local branch_changed = new_branch ~= old_branch
    local folder_changed = new_folder ~= old_folder

    if not branch_changed and not folder_changed then
      vim.notify('Name unchanged; nothing to do', vim.log.levels.INFO)
      return
    end

    local new_path = folder_changed and unique_path(parent .. '/' .. new_folder) or toplevel
    local final_folder = vim.fn.fnamemodify(new_path, ':t')

    local remote_line
    if not (upstream and remote) then
      remote_line = 'Remote:  (local only — unchanged)'
    elseif branch_changed then
      remote_line = string.format('Remote:  %s/%s  ->  %s/%s', remote, old_branch, remote, new_branch)
    else
      remote_line = string.format('Remote:  %s/%s  (unchanged)', remote, old_branch)
    end

    local summary = table.concat({
      'Rename this worktree?',
      string.format('Folder:  %s  ->  %s', old_folder, final_folder),
      string.format('Branch:  %s  ->  %s', old_branch, new_branch),
      remote_line,
    }, '\n')

    vim.ui.select({ 'Yes', 'No' }, { prompt = summary }, function(choice)
      if choice ~= 'Yes' then
        vim.notify('Rename cancelled', vim.log.levels.INFO)
        return
      end

      local steps = {}

      if branch_changed then
        steps[#steps + 1] = {
          label = 'Rename local branch',
          cmd = { 'git', '-C', main_repo, 'branch', '-m', old_branch, new_branch },
        }
      end

      if folder_changed then
        steps[#steps + 1] = {
          label = 'Move worktree folder',
          cmd = { 'git', '-C', main_repo, 'worktree', 'move', toplevel, new_path },
          -- Step out of the soon-to-be-moved directory so nvim's cwd never goes stale.
          before = function() pcall(vim.cmd, 'cd ' .. vim.fn.fnameescape(main_repo)) end,
          after = function()
            vim.cmd('cd ' .. vim.fn.fnameescape(new_path))
            repoint_buffers(toplevel, new_path)
          end,
        }
      end

      if upstream and remote and branch_changed then
        steps[#steps + 1] = {
          label = 'Push renamed branch',
          cmd = { 'git', '-C', main_repo, 'push', '-u', remote, new_branch },
        }
        steps[#steps + 1] = {
          label = 'Delete old remote branch',
          cmd = { 'git', '-C', main_repo, 'push', remote, '--delete', old_branch },
        }
      end

      run_sequence(steps, 1, function() vim.notify(string.format('Worktree renamed to "%s" (branch "%s")', final_folder, new_branch), vim.log.levels.INFO) end)
    end)
  end, old_folder)
end

-- Containers that hold linked worktrees (override via env to relocate them).
local WCREATED_DIR = vim.env.WCREATED_DIR or vim.fn.expand('$HOME/Programming/wcreated')
local WCHECKOUT_DIR = vim.env.WCHECKOUT_DIR or vim.fn.expand('$HOME/Programming/wcheckout')
local MAX_TAB_NAME_LENGTH = 20

--- Rename the focused Zellij tab to `name` (no-op outside Zellij), mirroring the
--- project switcher so switching a worktree keeps the tab label in sync.
---@param name string
local function rename_zellij_tab(name)
  if not vim.env.ZELLIJ then return end

  local tab_name = name:sub(1, MAX_TAB_NAME_LENGTH)
  local layout = vim.fn.system('zellij action dump-layout 2>/dev/null')
  local tab_index = 0
  for line in layout:gmatch('[^\n]+') do
    if line:match('^%s*tab%s.*name=') then
      tab_index = tab_index + 1
      if line:match('focus=true') then break end
    end
  end
  if tab_index > 0 then tab_name = tab_index .. '.' .. tab_name end
  vim.fn.system('zellij action rename-tab "' .. tab_name .. '"')
end

--- Collect linked worktrees from the wcreated/wcheckout containers, most recently
--- modified first.
---@return { name: string, path: string, origin: string, text: string, mtime: integer }[]
local function collect_worktrees()
  local sources = {
    { dir = WCREATED_DIR, origin = 'wcreated' },
    { dir = WCHECKOUT_DIR, origin = 'wcheckout' },
  }
  local items = {}
  for _, src in ipairs(sources) do
    for _, entry in ipairs(files.scan(src.dir, { type = 'directory' })) do
      local stat = vim.uv.fs_stat(entry.path)
      items[#items + 1] = {
        name = entry.name,
        path = entry.path,
        origin = src.origin,
        text = src.origin .. '/' .. entry.name,
        mtime = stat and stat.mtime and stat.mtime.sec or 0,
      }
    end
  end
  table.sort(items, function(a, b) return a.mtime > b.mtime end)
  return items
end

--- Pick a worktree (wcreated + wcheckout, most-recent first) and switch the editor
--- cwd to it, keeping the Zellij tab label in sync.
function M.switch_worktree()
  local worktrees = collect_worktrees()
  if #worktrees == 0 then
    vim.notify('No worktrees found in ' .. WCREATED_DIR .. ' or ' .. WCHECKOUT_DIR, vim.log.levels.WARN)
    return
  end

  local current = realpath(vim.fn.getcwd())

  ui.pick({
    title = 'Switch Worktree (' .. #worktrees .. ')',
    items = worktrees,
    format = function(item)
      local is_current = realpath(item.path) == current
      return {
        { is_current and ' ' or '  ', is_current and 'DiagnosticOk' or 'Comment' },
        { item.origin .. '/', 'Comment' },
        { item.name, is_current and 'DiagnosticOk' or 'Function' },
      }
    end,
    on_confirm = function(item)
      if realpath(item.path) == current then
        vim.notify('Already in ' .. item.text, vim.log.levels.INFO)
        return
      end
      vim.cmd('cd ' .. vim.fn.fnameescape(item.path))
      rename_zellij_tab(item.name)
      vim.notify('Switched to ' .. item.text, vim.log.levels.INFO)
    end,
    empty_msg = 'No worktrees to switch to',
  })
end

--- True when `path` resolves under either managed worktree container. Used to
--- gate the recursive directory cleanup so it can never escape wcreated/wcheckout.
---@param path string
---@return boolean
local function is_managed_path(path)
  local rp = realpath(path)
  return M.is_wcreated_path(rp, realpath(WCREATED_DIR)) or M.is_wcreated_path(rp, realpath(WCHECKOUT_DIR))
end

--- Run argv `steps` sequentially, best-effort: a non-zero exit is reported as a
--- warning but does not abort the chain. Each step: { label, cmd }.
local function run_best_effort(steps, idx, on_done)
  idx = idx or 1
  if idx > #steps then
    if on_done then on_done() end
    return
  end
  local step = steps[idx]
  async.run_cmd(step.cmd, function(res)
    if res.code ~= 0 then
      local err = (res.stderr ~= '' and res.stderr or res.stdout):gsub('%s+$', '')
      vim.notify(step.label .. ': ' .. (err ~= '' and err or 'failed'), vim.log.levels.WARN)
    end
    run_best_effort(steps, idx + 1, on_done)
  end)
end

--- Build the best-effort deletion argv steps for a worktree. Pure: the caller
--- resolves the facts (branch/remote existence, wcreated-ness) and passes them in.
--- The remote branch is deleted only for wcreated worktrees (delete_remote), never
--- for wcheckout -- the central safety rule mirrored from the worktree shell scripts.
---@param o { main_repo: string|nil, worktree: string, branch: string|nil, delete_remote: boolean, local_exists: boolean, remote_exists: boolean, remote: string|nil }
---@return { label: string, cmd: string[] }[]
function M.build_delete_steps(o)
  local steps = {}
  if not o.main_repo then return steps end
  steps[#steps + 1] = { label = 'Remove worktree', cmd = { 'git', '-C', o.main_repo, 'worktree', 'remove', '--force', o.worktree } }
  if o.branch and o.local_exists then steps[#steps + 1] = { label = 'Delete local branch', cmd = { 'git', '-C', o.main_repo, 'branch', '-D', o.branch } } end
  if o.branch and o.delete_remote and o.remote_exists then
    steps[#steps + 1] = { label = 'Delete remote branch', cmd = { 'git', '-C', o.main_repo, 'push', o.remote or 'origin', '--delete', o.branch } }
  end
  return steps
end

--- Resolve facts, confirm, then delete a single worktree (folder + local branch,
--- and the remote branch only for wcreated worktrees).
---@param item { path: string, text: string }
local function delete_worktree_entry(item)
  local wt = item.path
  local delete_remote = M.is_wcreated_path(realpath(wt), realpath(WCREATED_DIR))

  local branch = git_capture(wt, { 'branch', '--show-current' })
  if branch == '' then branch = nil end

  local common = git_capture(wt, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  local main_repo = common and vim.fn.fnamemodify(common, ':h') or nil

  local function ref_exists(prefix)
    if not (main_repo and branch) then return false end
    return git_capture(main_repo, { 'show-ref', '--verify', '--quiet', prefix .. branch }) ~= nil
  end
  local local_exists = ref_exists('refs/heads/')
  local remote_exists = ref_exists('refs/remotes/origin/')

  local remote_line
  if not branch then
    remote_line = 'Remote:  (no branch detected)'
  elseif delete_remote and remote_exists then
    remote_line = 'Remote:  origin/' .. branch .. '  (will be DELETED)'
  elseif delete_remote then
    remote_line = 'Remote:  origin/' .. branch .. '  (not found -- skipped)'
  else
    remote_line = 'Remote:  origin/' .. branch .. '  (preserved -- checkout worktree)'
  end

  local branch_label = 'Branch:  ' .. (branch or '(none)')
  if branch then branch_label = branch_label .. (local_exists and '  (local: delete)' or '  (local: not found)') end

  local summary = table.concat({
    'Delete this worktree?',
    'Folder:  ' .. item.text,
    'Path:    ' .. wt,
    branch_label,
    remote_line,
  }, '\n')

  vim.ui.select({ 'Yes', 'No' }, { prompt = summary }, function(choice)
    if choice ~= 'Yes' then
      vim.notify('Deletion cancelled', vim.log.levels.INFO)
      return
    end

    -- Never sit inside the directory we are about to delete.
    if main_repo and realpath(wt) == realpath(vim.fn.getcwd()) then
      vim.cmd('cd ' .. vim.fn.fnameescape(main_repo))
      vim.notify('Moved to main repo: ' .. main_repo, vim.log.levels.INFO)
    end

    local steps = M.build_delete_steps({
      main_repo = main_repo,
      worktree = wt,
      branch = branch,
      delete_remote = delete_remote,
      local_exists = local_exists,
      remote_exists = remote_exists,
      remote = 'origin',
    })

    run_best_effort(steps, 1, function()
      if vim.uv.fs_stat(wt) and is_managed_path(wt) then vim.fn.delete(wt, 'rf') end
      vim.notify('Deleted worktree "' .. item.text .. '"', vim.log.levels.INFO)
    end)
  end)
end

--- Pick a worktree (wcreated + wcheckout) and delete it after confirmation.
function M.delete_worktree()
  local worktrees = collect_worktrees()
  if #worktrees == 0 then
    vim.notify('No worktrees found in ' .. WCREATED_DIR .. ' or ' .. WCHECKOUT_DIR, vim.log.levels.WARN)
    return
  end

  local current = realpath(vim.fn.getcwd())

  ui.pick({
    title = 'Delete Worktree (' .. #worktrees .. ')',
    items = worktrees,
    format = function(item)
      local is_current = realpath(item.path) == current
      local origin_hl = item.origin == 'wcreated' and 'DiagnosticWarn' or 'Comment'
      return {
        { is_current and ' ' or '  ', is_current and 'DiagnosticOk' or 'Comment' },
        { item.origin .. '/', origin_hl },
        { item.name, 'Function' },
      }
    end,
    on_confirm = delete_worktree_entry,
    empty_msg = 'No worktrees to delete',
  })
end

return M
