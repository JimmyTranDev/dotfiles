local async = require('custom.utils.async')
local files = require('custom.utils.files')
local input = require('custom.utils.input')
local pr_ownership = require('custom.utils.pr_ownership')
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

--- Parse `git branch -r` output into a sorted, deduped list of branch names
--- under `remote` (default 'origin'); the `origin/HEAD -> ...` pointer is dropped.
--- Pure: the caller captures the listing so this is testable without git.
---@param out string
---@param remote? string
---@return string[]
function M.remote_branches_from_listing(out, remote)
  remote = remote or 'origin'
  local prefix = remote .. '/'
  local seen, list = {}, {}
  for line in (out or ''):gmatch('[^\n]+') do
    local b = line:gsub('^%s+', ''):gsub('%s+$', '')
    if b:sub(1, #prefix) == prefix and not b:find('%->') then
      b = b:sub(#prefix + 1)
      if b ~= 'HEAD' and not seen[b] then
        seen[b] = true
        list[#list + 1] = b
      end
    end
  end
  table.sort(list)
  return list
end

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

-- Containers that hold linked worktrees (override via env to relocate them).
-- Expanded and realpath'd so path comparisons and directory scans share one
-- canonical absolute path; realpath falls back to the expanded path until the
-- directory exists (containers are created lazily on first create/checkout).
local WCREATED_DIR = realpath(vim.fn.expand(vim.env.WCREATED_DIR or '$HOME/Programming/wcreated'))
local WCHECKOUT_DIR = realpath(vim.fn.expand(vim.env.WCHECKOUT_DIR or '$HOME/Programming/wcheckout'))

--- True when an (already realpath'd) worktree path lives under the wcreated dir,
--- i.e. a branch we own whose remote branch should also be deleted on cleanup.
local function is_wcreated(path_real)
  local prefix = WCREATED_DIR .. '/'
  return path_real:sub(1, #prefix) == prefix
end

--- Parse `git worktree list --porcelain` output into worktree records.
---@param out string
---@return { path: string, branch: string|nil, bare: boolean, detached: boolean }[]
local function parse_worktrees(out)
  local list = {}
  local cur
  for line in (out .. '\n'):gmatch('(.-)\n') do
    local path = line:match('^worktree (.+)$')
    if path then
      cur = { path = path, bare = false, detached = false }
      list[#list + 1] = cur
    elseif cur then
      if line == 'bare' then
        cur.bare = true
      elseif line == 'detached' then
        cur.detached = true
      else
        local branch = line:match('^branch refs/heads/(.+)$')
        if branch then cur.branch = branch end
      end
    end
  end
  return list
end

--- Remove each target worktree, then its local branch, then -- for wcreated
--- worktrees -- its remote branch. Sequential and best-effort: a failed step
--- warns and processing continues with the next worktree.
---@param main_repo string
---@param targets { path: string, branch: string|nil, delete_remote: boolean }[]
local function clear_targets(main_repo, targets)
  local cleared, failed = 0, 0

  local function finish()
    local msg = string.format('Cleared %d worktree(s)', cleared)
    if failed > 0 then msg = msg .. string.format(', %d failed', failed) end
    vim.notify(msg, failed > 0 and vim.log.levels.WARN or vim.log.levels.INFO)
  end

  local function process(i)
    if i > #targets then return finish() end

    local wt = targets[i]
    local folder = vim.fn.fnamemodify(wt.path, ':t')

    async.run_cmd({ 'git', '-C', main_repo, 'worktree', 'remove', wt.path, '--force' }, function(rm)
      if rm.code ~= 0 then
        local err = (rm.stderr ~= '' and rm.stderr or rm.stdout):gsub('%s+$', '')
        vim.notify(string.format('Failed to remove %s: %s', folder, err), vim.log.levels.ERROR)
        failed = failed + 1
        return process(i + 1)
      end

      local function done_one()
        cleared = cleared + 1
        process(i + 1)
      end

      if not wt.branch then return done_one() end

      async.run_cmd({ 'git', '-C', main_repo, 'branch', '-D', wt.branch }, function(br)
        if br.code ~= 0 then
          local err = (br.stderr ~= '' and br.stderr or br.stdout):gsub('%s+$', '')
          vim.notify(string.format('%s: local branch delete failed: %s', folder, err), vim.log.levels.WARN)
        end

        if not wt.delete_remote then return done_one() end

        pr_ownership.check(main_repo, wt.branch, function(blocked, reason)
          if blocked then
            vim.notify(string.format('%s: remote kept (%s)', wt.branch, reason), vim.log.levels.WARN)
            return done_one()
          end
          async.run_cmd({ 'git', '-C', main_repo, 'push', 'origin', '--delete', wt.branch }, function(push)
            if push.code ~= 0 then vim.notify(string.format('%s: remote branch delete failed (kept)', wt.branch), vim.log.levels.WARN) end
            done_one()
          end)
        end)
      end)
    end)
  end

  process(1)
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
        -- Keep the old remote branch when it carries an open PR owned by someone
        -- else; fail-open (any uncertainty still deletes it).
        local blocked, reason = pr_ownership.check_sync(main_repo, old_branch)
        if blocked then
          vim.notify(string.format('Keeping old remote branch %s (%s)', old_branch, reason), vim.log.levels.WARN)
        else
          steps[#steps + 1] = {
            label = 'Delete old remote branch',
            cmd = { 'git', '-C', main_repo, 'push', remote, '--delete', old_branch },
          }
        end
      end

      run_sequence(steps, 1, function() vim.notify(string.format('Worktree renamed to "%s" (branch "%s")', final_folder, new_branch), vim.log.levels.INFO) end)
    end)
  end, old_folder)
end

--- Clear (remove) every linked worktree of the current project: each worktree
--- and its local branch, plus the remote branch for wcreated worktrees. The
--- primary checkout and the worktree you are currently inside are never touched.
function M.clear_project_worktrees()
  local cwd = vim.fn.getcwd()

  local common = git_capture(cwd, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  if not common then
    vim.notify('Not inside a git repository', vim.log.levels.ERROR)
    return
  end
  local main_repo = vim.fn.fnamemodify(common, ':h')

  local out = git_capture(main_repo, { 'worktree', 'list', '--porcelain' })
  if not out then
    vim.notify('Could not list worktrees', vim.log.levels.ERROR)
    return
  end

  local current_top = git_capture(cwd, { 'rev-parse', '--show-toplevel' })
  local main_real = realpath(main_repo)
  local current_real = current_top and realpath(current_top) or nil

  local targets, skipped_current = {}, false
  for _, wt in ipairs(parse_worktrees(out)) do
    local wt_real = realpath(wt.path)
    if not (wt.bare or wt_real == main_real) then
      if current_real and wt_real == current_real then
        skipped_current = true
      else
        wt.delete_remote = is_wcreated(wt_real)
        targets[#targets + 1] = wt
      end
    end
  end

  if #targets == 0 then
    local msg = skipped_current and 'Only the current worktree is linked; nothing else to clear' or 'No linked worktrees to clear'
    vim.notify(msg, vim.log.levels.INFO)
    return
  end

  local lines = { string.format('Clear %d worktree(s) of this project?', #targets) }
  for _, wt in ipairs(targets) do
    local remote = wt.delete_remote and '  + delete remote' or '  (local only)'
    lines[#lines + 1] = string.format('- %s  [%s]%s', vim.fn.fnamemodify(wt.path, ':t'), wt.branch or '(detached)', remote)
  end
  if skipped_current then lines[#lines + 1] = '(current worktree skipped)' end

  vim.ui.select({ 'Yes', 'No' }, { prompt = table.concat(lines, '\n') }, function(choice)
    if choice ~= 'Yes' then
      vim.notify('Clear cancelled', vim.log.levels.INFO)
      return
    end
    clear_targets(main_repo, targets)
  end)
end

--- First of develop/main/master that exists as a local branch in `repo`, else nil.
local function detect_base(repo)
  for _, b in ipairs({ 'develop', 'main', 'master' }) do
    if git_capture(repo, { 'rev-parse', '--verify', '--quiet', 'refs/heads/' .. b }) then return b end
  end
  return nil
end

--- Linked worktrees of `main_repo` as { path, branch, text }, parsed from
--- `git worktree list --porcelain`. The primary worktree and any detached-HEAD
--- worktrees are excluded (only branches that can be merged + deleted remain).
local function list_linked_worktrees(main_repo)
  local out = git_capture(main_repo, { 'worktree', 'list', '--porcelain' })
  if not out then return {} end

  local entries, cur = {}, nil
  for line in out:gmatch('[^\n]+') do
    local path = line:match('^worktree (.+)$')
    if path then
      cur = { path = path }
      entries[#entries + 1] = cur
    elseif cur then
      local branch = line:match('^branch refs/heads/(.+)$')
      if branch then cur.branch = branch end
      if line == 'detached' then cur.detached = true end
    end
  end

  local linked = {}
  for _, e in ipairs(entries) do
    if e.branch and not e.detached and realpath(e.path) ~= realpath(main_repo) then
      e.text = folder_from_branch(e.branch) .. ' ' .. e.branch
      linked[#linked + 1] = e
    end
  end
  return linked
end

--- True when `cwd` is the same path as, or nested inside, `dir`.
local function is_inside(cwd, dir)
  local a, b = realpath(cwd), realpath(dir)
  return a == b or a:sub(1, #b + 1) == (b .. '/')
end

--- Select one of this project's linked worktrees, merge its branch into the base
--- branch (develop -> main -> master), then remove the worktree and delete the
--- branch locally and on the remote. The merge + cleanup run from the main
--- repository, mirroring /implement-worktree's Phase 7 (merge first, since
--- cleanup deletes the branch).
function M.merge_and_cleanup_worktree()
  local cwd = vim.fn.getcwd()

  local common = git_capture(cwd, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  if not common then
    vim.notify('Not inside a git repository', vim.log.levels.ERROR)
    return
  end
  local main_repo = vim.fn.fnamemodify(common, ':h')

  local base = detect_base(main_repo)
  if not base then
    vim.notify('No base branch (develop/main/master) found', vim.log.levels.ERROR)
    return
  end

  local worktrees = list_linked_worktrees(main_repo)

  ui.pick({
    title = string.format('Merge & clean up worktree (base: %s)', base),
    items = worktrees,
    empty_msg = 'No linked worktrees to merge for this project',
    format = function(item)
      return {
        { folder_from_branch(item.branch), 'Function' },
        { '  ' .. item.branch, 'Comment' },
      }
    end,
    on_confirm = function(item)
      if item.branch == base then
        vim.notify('Refusing: that worktree is on the base branch ' .. base, vim.log.levels.ERROR)
        return
      end

      local folder = vim.fn.fnamemodify(item.path, ':t')
      local summary = table.concat({
        'Merge & clean up this worktree?',
        string.format('Worktree:  %s', folder),
        string.format('Branch:    %s', item.branch),
        string.format('Base:      %s', base),
        '',
        string.format('- merge --no-ff %s into %s and push', item.branch, base),
        '- remove the worktree (--force)',
        string.format('- delete %s locally and on origin', item.branch),
      }, '\n')

      vim.ui.select({ 'Yes', 'No' }, { prompt = summary }, function(choice)
        if choice ~= 'Yes' then
          vim.notify('Merge & cleanup cancelled', vim.log.levels.INFO)
          return
        end

        local inside = is_inside(cwd, item.path)
        local steps = {
          { label = 'Switch to ' .. base, cmd = { 'git', '-C', main_repo, 'switch', base } },
          { label = 'Update ' .. base, cmd = { 'git', '-C', main_repo, 'pull', '--ff-only', 'origin', base } },
          { label = string.format('Merge %s into %s', item.branch, base), cmd = { 'git', '-C', main_repo, 'merge', '--no-ff', item.branch } },
          { label = 'Push ' .. base, cmd = { 'git', '-C', main_repo, 'push', 'origin', base } },
          {
            label = 'Remove worktree',
            cmd = { 'git', '-C', main_repo, 'worktree', 'remove', '--force', item.path },
            before = function()
              if inside then pcall(vim.cmd, 'cd ' .. vim.fn.fnameescape(main_repo)) end
            end,
          },
          { label = 'Delete local branch ' .. item.branch, cmd = { 'git', '-C', main_repo, 'branch', '-D', item.branch } },
        }

        run_sequence(steps, 1, function()
          pr_ownership.check(main_repo, item.branch, function(blocked, reason)
            if blocked then
              vim.notify(string.format('Merged & removed worktree; kept remote %s (%s)', item.branch, reason), vim.log.levels.WARN)
              return
            end
            vim.notify('Deleting remote branch ' .. item.branch .. '...', vim.log.levels.INFO)
            async.run_cmd({ 'git', '-C', main_repo, 'push', 'origin', '--delete', item.branch }, function(res)
              if res.code == 0 then
                vim.notify(string.format('Merged %s into %s and cleaned up the worktree', item.branch, base), vim.log.levels.INFO)
              else
                vim.notify(string.format('Merged & removed worktree; remote %s not deleted (already gone?)', item.branch), vim.log.levels.WARN)
              end
            end)
          end)
        end)
      end)
    end,
  })
end

--- Select one of this project's linked worktrees and open a diff review of its
--- branch against the base branch (develop -> main -> master), scoped to that
--- worktree. This is the "review this worktree before merging" view -- it mirrors
--- merge_and_cleanup_worktree's picker but shows the diff instead of merging.
function M.review_worktree_diff()
  local cwd = vim.fn.getcwd()

  local common = git_capture(cwd, { 'rev-parse', '--path-format=absolute', '--git-common-dir' })
  if not common then
    vim.notify('Not inside a git repository', vim.log.levels.ERROR)
    return
  end
  local main_repo = vim.fn.fnamemodify(common, ':h')

  local base = detect_base(main_repo)
  if not base then
    vim.notify('No base branch (develop/main/master) found', vim.log.levels.ERROR)
    return
  end

  local worktrees = list_linked_worktrees(main_repo)

  ui.pick({
    title = string.format('Review worktree diff (vs %s)', base),
    items = worktrees,
    empty_msg = 'No linked worktrees to review for this project',
    format = function(item)
      return {
        { folder_from_branch(item.branch), 'Function' },
        { '  ' .. item.branch, 'Comment' },
      }
    end,
    on_confirm = function(item)
      if item.branch == base then
        vim.notify('Nothing to review: that worktree is on the base branch ' .. base, vim.log.levels.INFO)
        return
      end
      local ok, snacks = pcall(require, 'snacks')
      if not ok then
        vim.notify('snacks.nvim is not available', vim.log.levels.WARN)
        return
      end
      snacks.picker.git_diff({ cwd = item.path, base = base })
    end,
  })
end

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

  -- PR-ownership guard: even for a wcreated branch, keep the remote when it has an
  -- open PR owned by someone else (fail-open on any uncertainty).
  local pr_block_reason
  if delete_remote and branch and remote_exists then
    local blocked, reason = pr_ownership.check_sync(main_repo, branch)
    if blocked then
      delete_remote = false
      pr_block_reason = reason
    end
  end

  local remote_line
  if not branch then
    remote_line = 'Remote:  (no branch detected)'
  elseif pr_block_reason then
    remote_line = 'Remote:  origin/' .. branch .. '  (kept -- ' .. pr_block_reason .. ')'
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

    -- Never sit inside the directory we are about to delete -- this also catches
    -- being in a subdirectory of it. Prefer the main repo; fall back to the
    -- worktree's parent container when the main repo cannot be resolved.
    if is_inside(vim.fn.getcwd(), wt) then
      local dest = main_repo or vim.fn.fnamemodify(wt, ':h')
      vim.cmd('cd ' .. vim.fn.fnameescape(dest))
      vim.notify('Moved out of the worktree to: ' .. dest, vim.log.levels.INFO)
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
      local function announce() vim.notify('Deleted worktree "' .. item.text .. '"', vim.log.levels.INFO) end
      -- If `worktree remove` failed but the folder is now gone, git still lists a
      -- stale worktree; prune reconciles it. A no-op when already consistent.
      if main_repo then
        async.run_cmd({ 'git', '-C', main_repo, 'worktree', 'prune' }, announce)
      else
        announce()
      end
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

-- Conventional-commit types offered when seeding a new worktree (feat first =
-- the default position), mirroring the worktree create script.
local COMMIT_TYPES = { 'feat', 'fix', 'docs', 'style', 'refactor', 'test', 'chore', 'revert', 'build', 'ci', 'perf' }

--- Node package-manager precedence (pnpm > yarn > bun > npm), mirroring the
--- shell `_detect_node_lock`. Pure: `has` reports whether a lockfile exists, so
--- the precedence can be tested without touching the filesystem.
---@param has fun(filename: string): boolean
---@return string|nil one of 'pnpm'|'yarn'|'bun'|'npm', or nil when none match
function M.detect_package_manager(has)
  if has('pnpm-lock.yaml') then return 'pnpm' end
  if has('yarn.lock') then return 'yarn' end
  if has('bun.lockb') or has('bun.lock') then return 'bun' end
  if has('package-lock.json') then return 'npm' end
  return nil
end

--- Detect the package manager for `dir` from its lockfiles (nil when none).
---@param dir string
---@return string|nil
local function detect_pm(dir)
  return M.detect_package_manager(function(f) return vim.uv.fs_stat(dir .. '/' .. f) ~= nil end)
end

--- Fetch a JIRA summary via `acli` (async), then call `cb(summary)`. Falls back
--- to `cb(nil)` when acli is missing, errors, or returns no usable summary --
--- the caller then uses the bare key as the branch name.
---@param key string
---@param cb fun(summary: string|nil)
local function fetch_jira_summary(key, cb)
  if vim.fn.executable('acli') == 0 then
    vim.notify('acli not found; using ' .. key .. ' as the branch name', vim.log.levels.WARN)
    return cb(nil)
  end
  vim.notify('Fetching JIRA summary for ' .. key .. '…', vim.log.levels.INFO)
  async.json({ 'acli', 'jira', 'workitem', 'view', key, '--json', '--fields', 'summary' }, function(data)
    local summary = type(data) == 'table' and type(data.fields) == 'table' and data.fields.summary or nil
    if type(summary) ~= 'string' or summary == '' or summary == 'null' then
      vim.notify('No JIRA summary found; using ' .. key, vim.log.levels.WARN)
      return cb(nil)
    end
    cb(summary)
  end, function(err)
    vim.notify('acli failed (' .. (err ~= '' and err or 'error') .. '); using ' .. key, vim.log.levels.WARN)
    cb(nil)
  end)
end

--- Pick the base branch and a non-mutating start point for a new worktree.
--- Tries develop -> main -> master, accepting either a local head or an
--- origin/<branch> remote ref; prefers origin/<branch> as the start point so the
--- new worktree is based on freshly fetched upstream without touching the user's
--- checked-out main repo (no stash/pull/pop). Returns nil when none exist.
---@param main_repo string
---@return string|nil base, string|nil start_point
local function resolve_base(main_repo)
  for _, b in ipairs({ 'develop', 'main', 'master' }) do
    local has_local = git_capture(main_repo, { 'show-ref', '--verify', '--quiet', 'refs/heads/' .. b }) ~= nil
    local has_remote = git_capture(main_repo, { 'show-ref', '--verify', '--quiet', 'refs/remotes/origin/' .. b }) ~= nil
    if has_local or has_remote then return b, (has_remote and ('origin/' .. b) or b) end
  end
  return nil, nil
end

--- Fetch origin, create the worktree on a fresh base, seed an empty commit, then
--- switch the editor into it (Zellij tab synced) and install node deps if any.
---@param ctx { main_repo: string, raw_input: string, summary: string|nil, branch_name: string, commit_type: string, target_dir: string }
local function run_create(ctx)
  local worktree_dir = unique_path(ctx.target_dir .. '/' .. ctx.branch_name)
  -- resolve_unique_dir may have suffixed the path; the branch tracks the folder.
  local branch = vim.fn.fnamemodify(worktree_dir, ':t')
  local commit_message = M.build_commit_message(ctx.commit_type, ctx.raw_input, ctx.summary)

  pcall(vim.fn.mkdir, ctx.target_dir, 'p')
  vim.notify('Fetching origin…', vim.log.levels.INFO)

  async.run_cmd({ 'git', '-C', ctx.main_repo, 'fetch', 'origin' }, function()
    -- Fetch is best-effort: fall through to local refs when offline.
    local base, start_point = resolve_base(ctx.main_repo)
    if not base then
      vim.notify('No base branch (develop/main/master) found in ' .. ctx.main_repo, vim.log.levels.ERROR)
      return
    end

    vim.notify('Creating worktree on ' .. start_point .. '…', vim.log.levels.INFO)
    -- --no-track keeps the feature branch upstream-less even when based on a
    -- remote ref, so a later `git push -u` sets the correct upstream.
    async.run_cmd({ 'git', '-C', ctx.main_repo, 'worktree', 'add', '--no-track', '-b', branch, worktree_dir, start_point }, function(res)
      if res.code ~= 0 then
        local err = (res.stderr ~= '' and res.stderr or res.stdout):gsub('%s+$', '')
        vim.notify('Failed to create worktree: ' .. err, vim.log.levels.ERROR)
        return
      end

      async.run_cmd({ 'git', '-C', worktree_dir, 'commit', '--allow-empty', '-m', commit_message }, function(cres)
        if cres.code ~= 0 then vim.notify('Warning: could not create the initial commit', vim.log.levels.WARN) end

        vim.cmd('cd ' .. vim.fn.fnameescape(worktree_dir))
        rename_zellij_tab(branch)

        if vim.uv.fs_stat(worktree_dir .. '/package.json') then
          local pm = detect_pm(worktree_dir) or 'npm'
          ui.exec_in_terminal(pm .. ' install', 'Installing dependencies (' .. pm .. ')…', { name = 'worktree-install' })
        end

        vim.notify(string.format('Created worktree "%s" from %s', branch, start_point), vim.log.levels.INFO)
      end)
    end)
  end)
end

--- Step 3: choose the commit type for the seed commit (feat is the default).
---@param ctx table
local function choose_commit_type(ctx)
  local items = {}
  for _, t in ipairs(COMMIT_TYPES) do
    items[#items + 1] = { text = t }
  end
  ui.pick({
    title = 'Create Worktree: commit type (branch ' .. ctx.branch_name .. ')',
    items = items,
    format = function(item) return { { item.text, 'Function' } } end,
    on_confirm = function(choice)
      ctx.commit_type = choice.text
      ctx.target_dir = WCREATED_DIR
      run_create(ctx)
    end,
    empty_msg = 'No commit types',
  })
end

--- Step 2: read a branch name or JIRA key; resolve a summary for JIRA keys.
---@param main_repo string
local function prompt_branch(main_repo)
  input.get_input('Branch name or JIRA key (e.g. ABC-123): ', function(raw)
    if not raw then
      vim.notify('Create cancelled', vim.log.levels.INFO)
      return
    end

    local function proceed(summary)
      local branch_name = M.compute_branch_name(raw, summary)
      if branch_name == '' then
        vim.notify('Invalid branch name', vim.log.levels.ERROR)
        return
      end
      choose_commit_type({ main_repo = main_repo, raw_input = raw, summary = summary, branch_name = branch_name })
    end

    if raw:match(JIRA_PATTERN) then
      fetch_jira_summary(raw, proceed)
    else
      proceed(nil)
    end
  end)
end

--- Step 1: pick a repository under ~/Programming, then drive the create flow:
--- repo -> branch/JIRA -> commit type -> fetch + worktree add + seed commit ->
--- cd in (Zellij tab synced) + optional dependency install.
function M.create_worktree()
  local repos = files.scan_programming()
  if #repos == 0 then
    vim.notify('No repositories found under ~/Programming', vim.log.levels.WARN)
    return
  end

  ui.pick({
    title = 'Create Worktree: repository (' .. #repos .. ')',
    items = repos,
    format = function(item)
      return {
        { item.org .. '/', 'Comment' },
        { item.name, 'Function' },
      }
    end,
    on_confirm = function(repo) prompt_branch(repo.path) end,
    empty_msg = 'No repositories found',
  })
end

--- Check out an existing remote branch as a worktree under WCHECKOUT_DIR,
--- tracking origin/<branch>. A wcheckout branch is owned elsewhere, so a later
--- delete preserves the remote -- never branch this off the base.
---@param main_repo string
---@param branch string
local function run_checkout(main_repo, branch)
  local target = unique_path(WCHECKOUT_DIR .. '/' .. folder_from_branch(branch))
  pcall(vim.fn.mkdir, WCHECKOUT_DIR, 'p')

  local local_exists = git_capture(main_repo, { 'show-ref', '--verify', '--quiet', 'refs/heads/' .. branch }) ~= nil
  local cmd = local_exists
      and { 'git', '-C', main_repo, 'worktree', 'add', target, branch }
      or { 'git', '-C', main_repo, 'worktree', 'add', target, '-b', branch, 'origin/' .. branch }

  vim.notify('Checking out ' .. branch .. '…', vim.log.levels.INFO)
  async.run_cmd(cmd, function(res)
    if res.code ~= 0 then
      local err = (res.stderr ~= '' and res.stderr or res.stdout):gsub('%s+$', '')
      vim.notify('Failed to check out worktree: ' .. err, vim.log.levels.ERROR)
      return
    end
    vim.cmd('cd ' .. vim.fn.fnameescape(target))
    rename_zellij_tab(folder_from_branch(branch))
    if vim.uv.fs_stat(target .. '/package.json') then
      local pm = detect_pm(target) or 'npm'
      ui.exec_in_terminal(pm .. ' install', 'Installing dependencies (' .. pm .. ')…', { name = 'worktree-install' })
    end
    vim.notify(string.format('Checked out "%s" into %s', branch, target), vim.log.levels.INFO)
  end)
end

--- Pick a repository, fetch origin, then pick a remote branch to check out as a
--- worktree under wcheckout (tracking origin/<branch>; remote preserved on delete).
function M.checkout_worktree()
  local repos = files.scan_programming()
  if #repos == 0 then
    vim.notify('No repositories found under ~/Programming', vim.log.levels.WARN)
    return
  end

  ui.pick({
    title = 'Checkout Worktree: repository (' .. #repos .. ')',
    items = repos,
    format = function(item)
      return { { item.org .. '/', 'Comment' }, { item.name, 'Function' } }
    end,
    on_confirm = function(repo)
      vim.notify('Fetching origin…', vim.log.levels.INFO)
      async.run_cmd({ 'git', '-C', repo.path, 'fetch', 'origin' }, function()
        local branches = M.remote_branches_from_listing(git_capture(repo.path, { 'branch', '-r' }) or '')
        local items = {}
        for _, b in ipairs(branches) do
          items[#items + 1] = { branch = b }
        end
        ui.pick({
          title = 'Checkout Worktree: remote branch (' .. #items .. ')',
          items = items,
          format = function(item) return { { item.branch, 'Function' } } end,
          on_confirm = function(item) run_checkout(repo.path, item.branch) end,
          empty_msg = 'No remote branches found',
        })
      end)
    end,
    empty_msg = 'No repositories found',
  })
end

return M
