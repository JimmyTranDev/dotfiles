local M = {}

---@param cmd string[]
---@param callback fun(result: table)
local function run_gh(cmd, callback)
  vim.system(cmd, { text = true }, vim.schedule_wrap(function(result)
    if result.code ~= 0 then
      local err = (result.stderr or ''):gsub('%s+$', '')
      if err:find('no pull requests found') or err:find('Could not resolve') then
        vim.notify('No PR found for current branch', vim.log.levels.WARN)
      else
        vim.notify('gh error: ' .. err, vim.log.levels.ERROR)
      end
      return
    end
    local ok, data = pcall(vim.fn.json_decode, result.stdout)
    if not ok or not data then
      vim.notify('Failed to parse gh output', vim.log.levels.ERROR)
      return
    end
    callback(data)
  end))
end

---@param conclusion string|nil
---@param state string|nil
---@return string icon
---@return string hl
local function check_icon(conclusion, state)
  conclusion = (conclusion or ''):upper()
  state = (state or ''):upper()

  if conclusion == 'SUCCESS' then
    return '', 'DiagnosticOk'
  elseif conclusion == 'FAILURE' or conclusion == 'CANCELLED' or conclusion == 'TIMED_OUT' then
    return '', 'DiagnosticError'
  elseif conclusion == 'SKIPPED' or conclusion == 'NEUTRAL' then
    return '󰍷', 'Comment'
  elseif state == 'PENDING' or state == 'IN_PROGRESS' or state == 'QUEUED' then
    return '', 'DiagnosticWarn'
  end
  return '?', 'Comment'
end

--- Show CI check results for current branch's PR in a Snacks picker
function M.show_ci_checks()
  run_gh({ 'gh', 'pr', 'checks', '--json', 'name,state,conclusion,detailsUrl' }, function(checks)
    if #checks == 0 then
      vim.notify('No CI checks found', vim.log.levels.INFO)
      return
    end

    local items = {}
    for _, check in ipairs(checks) do
      local icon, hl = check_icon(check.conclusion, check.state)
      table.insert(items, {
        text = icon .. ' ' .. (check.name or 'unknown'),
        icon_hl = hl,
        url = check.detailsUrl,
      })
    end

    local ok, snacks = pcall(require, 'snacks')
    if not ok then return end

    snacks.picker({
      title = 'CI Checks',
      items = items,
      format = function(item)
        return { { item.text, item.icon_hl } }
      end,
      confirm = function(picker, item)
        picker:close()
        if item and item.url then
          vim.ui.open(item.url)
        end
      end,
    })
  end)
end

--- Show PR review and merge status in a Snacks picker
function M.show_pr_status()
  run_gh({
    'gh', 'pr', 'view', '--json',
    'state,reviewDecision,mergeable,statusCheckRollup,reviews,number,title,url',
  }, function(pr)
    local items = {}

    table.insert(items, { text = '  PR #' .. (pr.number or '?') .. ': ' .. (pr.title or ''), url = pr.url })
    table.insert(items, { text = '  State: ' .. (pr.state or 'unknown') })

    local decision = pr.reviewDecision or 'NONE'
    local decision_hl = 'Comment'
    if decision == 'APPROVED' then
      decision_hl = 'DiagnosticOk'
    elseif decision == 'CHANGES_REQUESTED' then
      decision_hl = 'DiagnosticError'
    elseif decision == 'REVIEW_REQUIRED' then
      decision_hl = 'DiagnosticWarn'
    end
    table.insert(items, { text = '  Review: ' .. decision, hl = decision_hl })

    local mergeable = pr.mergeable or 'UNKNOWN'
    local merge_hl = 'Comment'
    if mergeable == 'MERGEABLE' then
      merge_hl = 'DiagnosticOk'
    elseif mergeable == 'CONFLICTING' then
      merge_hl = 'DiagnosticError'
    end
    table.insert(items, { text = '  Mergeable: ' .. mergeable, hl = merge_hl })

    if pr.reviews and #pr.reviews > 0 then
      table.insert(items, { text = '' })
      table.insert(items, { text = '󰀨  Reviewers' })
      local seen = {}
      for i = #pr.reviews, 1, -1 do
        local review = pr.reviews[i]
        local author = review.author and review.author.login or 'unknown'
        if not seen[author] then
          seen[author] = true
          local state = review.state or 'PENDING'
          local icon = ''
          if state == 'APPROVED' then
            icon = ''
          elseif state == 'CHANGES_REQUESTED' then
            icon = ''
          elseif state == 'COMMENTED' then
            icon = '󰍷'
          end
          table.insert(items, { text = '  ' .. icon .. ' ' .. author .. ' (' .. state .. ')' })
        end
      end
    end

    if pr.statusCheckRollup and #pr.statusCheckRollup > 0 then
      local pass_count = 0
      local fail_count = 0
      local pending_count = 0
      for _, check in ipairs(pr.statusCheckRollup) do
        local conclusion = (check.conclusion or ''):upper()
        local state = (check.state or ''):upper()
        if conclusion == 'SUCCESS' then
          pass_count = pass_count + 1
        elseif conclusion == 'FAILURE' then
          fail_count = fail_count + 1
        elseif state == 'PENDING' or state == 'IN_PROGRESS' then
          pending_count = pending_count + 1
        end
      end
      table.insert(items, { text = '' })
      table.insert(items, { text = '  CI: ' .. pass_count .. ' pass, ' .. fail_count .. ' fail, ' .. pending_count .. ' pending' })
    end

    local ok, snacks = pcall(require, 'snacks')
    if not ok then return end

    snacks.picker({
      title = 'PR Status',
      items = items,
      format = function(item)
        return { { item.text, item.hl or 'Normal' } }
      end,
      confirm = function(picker, item)
        picker:close()
        if item and item.url then
          vim.ui.open(item.url)
        end
      end,
    })
  end)
end

--- Show combined CI + PR status overview
function M.show_pipeline_overview()
  local results = {}
  local pending = 2

  local function try_finish()
    pending = pending - 1
    if pending > 0 then return end

    local items = {}
    local pr = results.pr
    local checks = results.checks

    if pr then
      table.insert(items, { text = '  PR #' .. (pr.number or '?') .. ': ' .. (pr.title or ''), url = pr.url })
      local decision = pr.reviewDecision or 'NONE'
      local decision_hl = 'Comment'
      if decision == 'APPROVED' then
        decision_hl = 'DiagnosticOk'
      elseif decision == 'CHANGES_REQUESTED' then
        decision_hl = 'DiagnosticError'
      end
      table.insert(items, { text = '  Review: ' .. decision .. ' | Mergeable: ' .. (pr.mergeable or '?'), hl = decision_hl })
      table.insert(items, { text = '' })
    end

    if checks and #checks > 0 then
      table.insert(items, { text = '  CI Checks' })
      for _, check in ipairs(checks) do
        local icon, hl = check_icon(check.conclusion, check.state)
        table.insert(items, {
          text = '  ' .. icon .. ' ' .. (check.name or 'unknown'),
          hl = hl,
          url = check.detailsUrl,
        })
      end
    elseif not pr then
      vim.notify('No PR found for current branch', vim.log.levels.WARN)
      return
    end

    local ok, snacks = pcall(require, 'snacks')
    if not ok then return end

    snacks.picker({
      title = 'Pipeline Overview',
      items = items,
      format = function(item)
        return { { item.text, item.hl or 'Normal' } }
      end,
      confirm = function(picker, item)
        picker:close()
        if item and item.url then
          vim.ui.open(item.url)
        end
      end,
    })
  end

  vim.system(
    { 'gh', 'pr', 'view', '--json', 'state,reviewDecision,mergeable,number,title,url' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 then
        local ok, data = pcall(vim.fn.json_decode, result.stdout)
        if ok and data then
          results.pr = data
        end
      end
      try_finish()
    end)
  )

  vim.system(
    { 'gh', 'pr', 'checks', '--json', 'name,state,conclusion,detailsUrl' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 then
        local ok, data = pcall(vim.fn.json_decode, result.stdout)
        if ok and data then
          results.checks = data
        end
      end
      try_finish()
    end)
  )
end

return M
