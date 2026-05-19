local M = {}

local dashboard_win = nil

local function run_git(args, callback)
  vim.system(args, { text = true }, vim.schedule_wrap(function(result) callback(result.code == 0 and result.stdout or nil) end))
end

local function get_branch_info(callback)
  run_git({ 'git', 'branch', '--show-current' }, function(stdout)
    if not stdout then
      callback({ '  Branch: Not a git repo', 'DiagnosticError' })
      return
    end

    local branch = vim.trim(stdout)
    run_git({ 'git', 'rev-list', '--count', '--left-right', '@{upstream}...HEAD' }, function(upstream_stdout)
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
  run_git({ 'git', 'status', '--porcelain' }, function(stdout)
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
  run_git({ 'git', 'stash', 'list' }, function(stdout)
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
  run_git({ 'git', 'log', '--oneline', '@{upstream}..HEAD' }, function(stdout)
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
  vim.system(
    { 'gh', 'pr', 'view', '--json', 'number,title,state,reviewDecision,mergeable' },
    { text = true },
    vim.schedule_wrap(function(result)
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
  )
end

local function show_dashboard(results)
  local lines = { { '── Git Status Dashboard ──', 'Title' }, { '', nil } }
  for _, r in ipairs(results) do
    if r then table.insert(lines, r) end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  local content = {}
  local highlights = {}

  for i, line in ipairs(lines) do
    table.insert(content, line[1])
    if line[2] then table.insert(highlights, { i - 1, line[2] }) end
  end

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'

  local width = 60
  for _, line in ipairs(content) do
    width = math.max(width, vim.fn.strdisplaywidth(line) + 4)
  end
  width = math.min(width, math.floor(vim.o.columns * 0.8))

  local height = math.min(#content, math.floor(vim.o.lines * 0.6))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' Git Dashboard ',
    title_pos = 'center',
  })

  dashboard_win = win

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(buf, -1, hl[2], hl[1], 0, -1)
  end

  local function close_win()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
      dashboard_win = nil
    end
  end

  vim.keymap.set('n', 'q', close_win, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close_win, { buffer = buf, nowait = true })
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
