local async = require('custom.utils.async')
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
local function folder_from_branch(branch)
  local folder = branch:match('^[^/]+/(.+)$') or branch
  return (folder:gsub('/', '-'))
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

local WCREATED_DIR = realpath(vim.fn.expand(vim.env.WCREATED_DIR or '$HOME/Programming/wcreated'))

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

        async.run_cmd({ 'git', '-C', main_repo, 'push', 'origin', '--delete', wt.branch }, function(push)
          if push.code ~= 0 then vim.notify(string.format('%s: remote branch delete failed (kept)', wt.branch), vim.log.levels.WARN) end
          done_one()
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
        steps[#steps + 1] = {
          label = 'Delete old remote branch',
          cmd = { 'git', '-C', main_repo, 'push', remote, '--delete', old_branch },
        }
      end

      run_sequence(steps, 1, function()
        vim.notify(string.format('Worktree renamed to "%s" (branch "%s")', final_folder, new_branch), vim.log.levels.INFO)
      end)
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
    end,
  })
end

return M
