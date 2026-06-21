local async = require('custom.utils.async')

local M = {}

local dashboard_win = nil

local function get_branch_info(callback)
  async.run_cmd({ 'git', 'branch', '--show-current' }, function(result)
    local stdout = result.code == 0 and result.stdout or nil
    if not stdout then
      callback({ '  Branch: Not a git repo', 'DiagnosticError' })
      return
    end

    local branch = vim.trim(stdout)
    async.run_cmd({ 'git', 'rev-list', '--count', '--left-right', '@{upstream}...HEAD' }, function(upstream_result)
      local upstream_stdout = upstream_result.code == 0 and upstream_result.stdout or nil
      if not upstream_stdout then
        callback({ '  Branch: ' .. branch .. ' (no upstream)', 'DiagnosticWarn' })
        return
      end

      local behind, ahead = upstream_stdout:match('(%d+)%s+(%d+)')
      behind = tonumber(behind) or 0
      ahead = tonumber(ahead) or 0

      local parts = { '  Branch: ' .. branch }
      if ahead > 0 then table.insert(parts, '↑' .. ahead) end
      if behind > 0 then table.insert(parts, '↓' .. behind) end

      local hl = 'DiagnosticOk'
      if ahead > 0 or behind > 0 then hl = 'DiagnosticWarn' end

      callback({ table.concat(parts, ' '), hl })
    end)
  end)
end

local function get_dirty_files(callback)
  async.run_cmd({ 'git', 'status', '--porcelain' }, function(result)
    local stdout = result.code == 0 and result.stdout or nil
    if not stdout then
      callback({ '  Files: Error', 'DiagnosticError' })
      return
    end

    local staged, modified, untracked = 0, 0, 0
    for line in stdout:gmatch('[^\n]+') do
      local x, y = line:sub(1, 1), line:sub(2, 2)
      if x == '?' then
        untracked = untracked + 1
      else
        if x ~= ' ' and x ~= '?' then staged = staged + 1 end
        if y ~= ' ' and y ~= '?' then modified = modified + 1 end
      end
    end

    local total = staged + modified + untracked
    if total == 0 then
      callback({ '  Files: Clean', 'DiagnosticOk' })
      return
    end

    local parts = {}
    if staged > 0 then table.insert(parts, staged .. ' staged') end
    if modified > 0 then table.insert(parts, modified .. ' modified') end
    if untracked > 0 then table.insert(parts, untracked .. ' untracked') end
    callback({ '  Files: ' .. table.concat(parts, ', '), 'DiagnosticWarn' })
  end)
end

local function get_stash_count(callback)
  async.run_cmd({ 'git', 'stash', 'list' }, function(result)
    local stdout = result.code == 0 and result.stdout or nil
    if not stdout then
      callback({ '  Stash: Error', 'DiagnosticError' })
      return
    end

    local count = 0
    for _ in stdout:gmatch('[^\n]+') do
      count = count + 1
    end

    if count == 0 then
      callback({ '  Stash: Empty', 'DiagnosticOk' })
    else
      callback({ '  Stash: ' .. count .. ' entries', 'DiagnosticHint' })
    end
  end)
end

local function get_unpushed_commits(callback)
  async.run_cmd({ 'git', 'log', '--oneline', '@{upstream}..HEAD' }, function(result)
    local stdout = result.code == 0 and result.stdout or nil
    if not stdout then
      callback({ '  Unpushed: N/A (no upstream)', 'DiagnosticHint' })
      return
    end

    local count = 0
    local first_msg = nil
    for line in stdout:gmatch('[^\n]+') do
      count = count + 1
      if count == 1 then first_msg = line:match('^%S+%s+(.+)$') end
    end

    if count == 0 then
      callback({ '  Unpushed: None', 'DiagnosticOk' })
    elseif count == 1 then
      callback({ '  Unpushed: 1 commit — ' .. (first_msg or ''), 'DiagnosticWarn' })
    else
      callback({ '  Unpushed: ' .. count .. ' commits', 'DiagnosticWarn' })
    end
  end)
end

local function get_pr_status(callback)
  async.run_cmd({ 'gh', 'pr', 'view', '--json', 'number,title,state,reviewDecision,mergeable' }, function(result)
    if result.code ~= 0 then
      callback({ '  PR: No open PR for this branch', 'DiagnosticHint' })
      return
    end

    local ok, data = pcall(vim.json.decode, result.stdout or '')
    if not ok or not data or not data.number then
      callback({ '  PR: No open PR for this branch', 'DiagnosticHint' })
      return
    end

    local status_parts = { '#' .. data.number .. ' ' .. (data.title or '') }
    local hl = 'DiagnosticOk'

    if data.state == 'MERGED' then
      table.insert(status_parts, '[merged]')
    elseif data.state == 'CLOSED' then
      table.insert(status_parts, '[closed]')
      hl = 'DiagnosticError'
    else
      if data.reviewDecision == 'APPROVED' then
        table.insert(status_parts, '[approved]')
      elseif data.reviewDecision == 'CHANGES_REQUESTED' then
        table.insert(status_parts, '[changes requested]')
        hl = 'DiagnosticError'
      elseif data.reviewDecision == 'REVIEW_REQUIRED' then
        table.insert(status_parts, '[review needed]')
        hl = 'DiagnosticWarn'
      end

      if data.mergeable == 'CONFLICTING' then
        table.insert(status_parts, '[conflicts]')
        hl = 'DiagnosticError'
      end
    end

    callback({ '  PR: ' .. table.concat(status_parts, ' '), hl })
  end)
end

local function show_dashboard(results)
  local lines = { { '── Git Status Dashboard ──', 'Title' }, { '', nil } }
  for _, r in ipairs(results) do
    if r then table.insert(lines, r) end
  end

  dashboard_win = require('custom.utils.ui').show_panel({ title = 'Git Dashboard', lines = lines })
end

function M.git_dashboard()
  if dashboard_win and vim.api.nvim_win_is_valid(dashboard_win) then
    vim.api.nvim_win_close(dashboard_win, true)
    dashboard_win = nil
  end

  local results = { nil, nil, nil, nil, nil }
  local pending = 5

  local function maybe_show()
    pending = pending - 1
    if pending > 0 then return end
    show_dashboard(results)
  end

  get_branch_info(function(r)
    results[1] = r
    maybe_show()
  end)

  get_dirty_files(function(r)
    results[2] = r
    maybe_show()
  end)

  get_stash_count(function(r)
    results[3] = r
    maybe_show()
  end)

  get_unpushed_commits(function(r)
    results[4] = r
    maybe_show()
  end)

  get_pr_status(function(r)
    results[5] = r
    maybe_show()
  end)
end

return M
