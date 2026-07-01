local async = require('custom.utils.async')
local ui = require('custom.utils.ui')

local M = {}

local STALE_DAYS = 30

local function parse_branches(stdout)
  local branches = {}
  local now = os.time()
  local stale_threshold = now - (STALE_DAYS * 86400)

  for line in stdout:gmatch('[^\n]+') do
    local date_str, name = line:match('^(%d%d%d%d%-%d%d%-%d%d)%s+(.+)$')
    if date_str and name then
      name = name:match('^%s*(.-)%s*$')
      if name ~= '' then
        local y, m, d = date_str:match('(%d+)-(%d+)-(%d+)')
        local branch_time = os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 0, min = 0, sec = 0 })
        if branch_time <= stale_threshold then
          local days_old = math.floor((now - branch_time) / 86400)
          table.insert(branches, {
            name = name,
            date = date_str,
            days_old = days_old,
          })
        end
      end
    end
  end

  table.sort(branches, function(a, b) return a.days_old > b.days_old end)
  return branches
end

local function check_merged_status(branches, callback)
  if #branches == 0 then
    callback(branches)
    return
  end

  local pending = #branches

  for _, branch in ipairs(branches) do
    async.run_cmd({ 'git', 'branch', '--merged', 'HEAD', '--list', branch.name }, function(result)
      branch.merged = result.code == 0 and result.stdout:match('%S') ~= nil
      pending = pending - 1
      if pending == 0 then callback(branches) end
    end)
  end
end

local function find_worktree_for_branch(branch_name, callback)
  async.run_cmd({ 'git', 'worktree', 'list', '--porcelain' }, function(result)
    if result.code ~= 0 then
      callback(nil)
      return
    end

    local current_path = nil
    for line in result.stdout:gmatch('[^\n]+') do
      local path = line:match('^worktree (.+)$')
      if path then current_path = path end
      local b = line:match('^branch refs/heads/(.+)$')
      if b and b == branch_name and current_path then
        callback(current_path)
        return
      end
    end
    callback(nil)
  end)
end

local function delete_branch(branch, on_done)
  local function do_delete()
    local flag = branch.merged and '-d' or '-D'
    async.run_cmd({ 'git', 'branch', flag, branch.name }, function(result)
      if result.code == 0 then
        async.run_cmd({ 'git', 'push', 'origin', '--delete', branch.name }, function(push_result)
          if push_result.code == 0 then
            vim.notify('Deleted branch and remote: ' .. branch.name, vim.log.levels.INFO)
          else
            vim.notify('Deleted local branch: ' .. branch.name .. ' (remote delete failed)', vim.log.levels.WARN)
          end
          if on_done then on_done() end
        end)
      else
        vim.notify('Failed to delete branch: ' .. (result.stderr or ''), vim.log.levels.ERROR)
        if on_done then on_done() end
      end
    end)
  end

  find_worktree_for_branch(branch.name, function(worktree_path)
    if worktree_path then
      async.run_cmd({ 'git', 'worktree', 'remove', worktree_path, '--force' }, function(wt_result)
        if wt_result.code == 0 then
          vim.notify('Removed worktree: ' .. worktree_path, vim.log.levels.INFO)
          do_delete()
        else
          vim.notify('Failed to remove worktree, branch delete aborted: ' .. (wt_result.stderr or ''), vim.log.levels.ERROR)
          if on_done then on_done() end
        end
      end)
    else
      do_delete()
    end
  end)
end

function M.stale_branch_cleanup()
  return function()
    async.run_cmd({ 'git', 'branch', '--sort=committerdate', '--format=%(committerdate:short) %(refname:short)' }, function(result)
      if result.code ~= 0 then
        vim.notify('Failed to list branches: ' .. (result.stderr or ''), vim.log.levels.ERROR)
        return
      end

      local branches = parse_branches(result.stdout)

      check_merged_status(branches, function(checked_branches)
        if #checked_branches == 0 then
          vim.notify('No stale branches (older than ' .. STALE_DAYS .. ' days)', vim.log.levels.INFO)
          return
        end

        local items = {}
        for _, branch in ipairs(checked_branches) do
          local merged_indicator = branch.merged and ' [merged]' or ' [unmerged]'
          table.insert(items, {
            text = string.format('%s (%dd old)%s', branch.name, branch.days_old, merged_indicator),
            branch = branch,
          })
        end

        ui.pick({
          title = string.format('Stale Branches (%d found, >%dd old)', #items, STALE_DAYS),
          items = items,
          format = function(item)
            local hl = item.branch.merged and 'DiagnosticOk' or 'DiagnosticWarn'
            return { { item.text, hl } }
          end,
          on_confirm = function(item)
            local msg = string.format('Delete branch "%s"?', item.branch.name)
            if not item.branch.merged then msg = msg .. ' (WARNING: unmerged)' end
            vim.ui.select({ 'Yes', 'No' }, { prompt = msg }, function(choice)
              if choice == 'Yes' then delete_branch(item.branch) end
            end)
          end,
        })
      end)
    end)
  end
end

--- Parse `git branch -r` output into a sorted, deduped list of branch names
--- under `remote` (default 'origin'); the `origin/HEAD -> ...` pointer is dropped.
--- Pure: the caller captures the listing, so this is testable without git.
---@param out string
---@param remote? string
---@return string[]
function M.parse_remote_branches(out, remote)
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

--- Base branches never offered for remote deletion; the current branch is added
--- to this set at call time. Deleting any of these on the remote is destructive.
local DEFAULT_PROTECTED = { 'main', 'master', 'develop' }

--- Filter a remote-branch list to the names safe to delete: drop the protected
--- set (default main/master/develop) and the current branch. Order is preserved.
--- Pure/testable.
---@param names string[]
---@param current string|nil currently checked-out branch
---@param protected? string[] override the default protected set
---@return string[]
function M.deletable_remote_branches(names, current, protected)
  protected = protected or DEFAULT_PROTECTED
  local blocked = {}
  for _, name in ipairs(protected) do
    blocked[name] = true
  end
  if current and current ~= '' then blocked[current] = true end

  local out = {}
  for _, name in ipairs(names or {}) do
    if not blocked[name] then out[#out + 1] = name end
  end
  return out
end

--- Build the argv that deletes `branch` on `remote` (default 'origin'). Deleting
--- the remote ref also drops the local `<remote>/<branch>` tracking ref. Pure.
---@param branch string
---@param remote? string
---@return string[]
function M.build_delete_remote_cmd(branch, remote) return { 'git', 'push', remote or 'origin', '--delete', branch } end

--- Delete each already-confirmed remote branch on origin, collecting a summary.
--- Best-effort and concurrent: a failed delete is reported but does not abort the
--- rest. Deleting the remote ref also drops its `origin/<branch>` tracking ref.
---@param names string[]
local function delete_remote_branches_now(names)
  local total = #names
  local done, ok_count = 0, 0
  for _, name in ipairs(names) do
    async.run_cmd(M.build_delete_remote_cmd(name), function(res)
      done = done + 1
      if res.code == 0 then
        ok_count = ok_count + 1
      else
        vim.notify(string.format('Failed to delete origin/%s: %s', name, (res.stderr or ''):gsub('%s+$', '')), vim.log.levels.ERROR)
      end
      if done == total then
        local level = ok_count == total and vim.log.levels.INFO or vim.log.levels.WARN
        vim.notify(string.format('Deleted %d/%d remote branch(es) on origin', ok_count, total), level)
      end
    end)
  end
end

--- Destructive Yes/No gate before deleting the picked branches on the remote.
---@param items { branch: string }[]
local function confirm_and_delete_remote(items)
  local names = {}
  for _, item in ipairs(items) do
    names[#names + 1] = item.branch
  end
  local prompt = string.format('Delete %d remote branch(es) on origin? This cannot be undone.', #names)
  vim.ui.select({ 'Yes', 'No' }, { prompt = prompt }, function(choice)
    if choice == 'Yes' then delete_remote_branches_now(names) end
  end)
end

--- List the current repo's remote branches, multi-select them in a picker
--- (<Tab>/<S-Tab> to toggle, <Enter> to confirm), then delete the selected
--- branches on origin after a confirmation. Remote-only: local branches and
--- worktrees are left untouched. Base branches (main/master/develop) and the
--- current branch are excluded from the list as a safety guard.
function M.delete_remote_branches()
  async.run_cmd({ 'git', 'rev-parse', '--is-inside-work-tree' }, function(wt)
    if wt.code ~= 0 or not (wt.stdout or ''):match('true') then
      vim.notify('Not inside a git repository', vim.log.levels.WARN)
      return
    end

    async.run_cmd({ 'git', 'fetch', '--prune', 'origin' }, function(fetch)
      if fetch.code ~= 0 then vim.notify('git fetch --prune failed; listing cached remote branches', vim.log.levels.WARN) end

      async.run_cmd({ 'git', 'branch', '-r' }, function(result)
        if result.code ~= 0 then
          vim.notify('Failed to list remote branches: ' .. (result.stderr or ''), vim.log.levels.ERROR)
          return
        end

        async.run_cmd({ 'git', 'rev-parse', '--abbrev-ref', 'HEAD' }, function(head)
          local current = head.code == 0 and (head.stdout or ''):gsub('%s+$', '') or ''
          local names = M.deletable_remote_branches(M.parse_remote_branches(result.stdout), current)
          if #names == 0 then
            vim.notify('No deletable remote branches (base + current excluded)', vim.log.levels.INFO)
            return
          end

          local items = {}
          for _, name in ipairs(names) do
            items[#items + 1] = { text = name, branch = name }
          end

          ui.pick({
            title = string.format('Delete remote branches — %d (Tab select, Enter confirm)', #items),
            items = items,
            format = function(item) return { { item.text, 'DiagnosticWarn' } } end,
            extra = {
              confirm = function(picker)
                picker:close()
                local chosen = picker:selected({ fallback = true })
                if chosen and #chosen > 0 then confirm_and_delete_remote(chosen) end
              end,
            },
          })
        end)
      end)
    end)
  end)
end

return M
