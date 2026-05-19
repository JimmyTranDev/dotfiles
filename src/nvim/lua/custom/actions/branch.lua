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
    vim.system(
      { 'git', 'branch', '--merged', 'HEAD', '--list', branch.name },
      { text = true },
      vim.schedule_wrap(function(result)
        branch.merged = result.code == 0 and result.stdout:match('%S') ~= nil
        pending = pending - 1
        if pending == 0 then callback(branches) end
      end)
    )
  end
end

local function find_worktree_for_branch(branch_name, callback)
  vim.system(
    { 'git', 'worktree', 'list', '--porcelain' },
    { text = true },
    vim.schedule_wrap(function(result)
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
  )
end

local function delete_branch(branch, on_done)
  local function do_delete()
    local flag = branch.merged and '-d' or '-D'
    vim.system(
      { 'git', 'branch', flag, branch.name },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 then
          vim.system(
            { 'git', 'push', 'origin', '--delete', branch.name },
            { text = true },
            vim.schedule_wrap(function(push_result)
              if push_result.code == 0 then
                vim.notify('Deleted branch and remote: ' .. branch.name, vim.log.levels.INFO)
              else
                vim.notify('Deleted local branch: ' .. branch.name .. ' (remote delete failed)', vim.log.levels.WARN)
              end
              if on_done then on_done() end
            end)
          )
        else
          vim.notify('Failed to delete branch: ' .. (result.stderr or ''), vim.log.levels.ERROR)
          if on_done then on_done() end
        end
      end)
    )
  end

  find_worktree_for_branch(branch.name, function(worktree_path)
    if worktree_path then
      vim.system(
        { 'git', 'worktree', 'remove', worktree_path, '--force' },
        { text = true },
        vim.schedule_wrap(function(wt_result)
          if wt_result.code == 0 then
            vim.notify('Removed worktree: ' .. worktree_path, vim.log.levels.INFO)
            do_delete()
          else
            vim.notify('Failed to remove worktree, branch delete aborted: ' .. (wt_result.stderr or ''), vim.log.levels.ERROR)
            if on_done then on_done() end
          end
        end)
      )
    else
      do_delete()
    end
  end)
end

function M.stale_branch_cleanup()
  return function()
    vim.system(
      { 'git', 'branch', '--sort=committerdate', '--format=%(committerdate:short) %(refname:short)' },
      { text = true },
      vim.schedule_wrap(function(result)
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

          local snacks_ok, snacks = pcall(require, 'snacks')
          if not snacks_ok then return end

          snacks.picker({
            title = string.format('Stale Branches (%d found, >%dd old)', #items, STALE_DAYS),
            items = items,
            format = function(item)
              local hl = item.branch.merged and 'DiagnosticOk' or 'DiagnosticWarn'
              return { { item.text, hl } }
            end,
            confirm = function(picker, item)
              picker:close()
              local msg = string.format('Delete branch "%s"?', item.branch.name)
              if not item.branch.merged then msg = msg .. ' (WARNING: unmerged)' end
              vim.ui.select({ 'Yes', 'No' }, { prompt = msg }, function(choice)
                if choice == 'Yes' then delete_branch(item.branch) end
              end)
            end,
          })
        end)
      end)
    )
  end
end

return M
