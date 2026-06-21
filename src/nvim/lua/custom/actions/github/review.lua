local github_utils = require('custom.utils.github')
local file_utils = require('custom.utils.files')
local async_utils = require('custom.utils.async')

local M = {}

function M.pr_review_mode()
  local repo_info = github_utils.get_repo_info()
  local repo_slug = repo_info and repo_info.nameWithOwner or ''

  async_utils.run('gh pr list --json number,title,headRefName,author --limit 20', function(stdout)
    local ok, prs = pcall(vim.json.decode, stdout)
    if not ok or not prs or #prs == 0 then
      vim.notify('No open PRs found in this repo', vim.log.levels.INFO)
      return
    end

    local pr_items = {}
    for _, pr in ipairs(prs) do
      local author = type(pr.author) == 'table' and pr.author.login or tostring(pr.author or '')
      table.insert(pr_items, {
        text = string.format('#%d %s (%s)', pr.number, pr.title, author),
        number = pr.number,
        title = pr.title,
        branch = pr.headRefName,
        author = author,
      })
    end

    local snacks_ok, snacks = pcall(require, 'snacks')
    if not snacks_ok then return end

    snacks.picker({
      title = 'Select PR to Review',
      items = pr_items,
      format = function(item) return { { item.text, 'Normal' } } end,
      confirm = function(picker, item)
        picker:close()
        M._open_pr_review(item.number, item.title, repo_slug)
      end,
    })
  end, function(_, err) vim.notify('Failed to list PRs: ' .. err, vim.log.levels.ERROR) end)
end

local function parse_diff_by_file(full_diff)
  local file_diffs = {}
  local current_file = nil
  local current_lines = {}

  for line in (full_diff .. '\n'):gmatch('([^\n]*)\n') do
    local new_file = line:match('^diff %-%-git a/(.*) b/')
    if new_file then
      if current_file then file_diffs[current_file] = table.concat(current_lines, '\n') end
      current_file = new_file
      current_lines = { line }
    elseif current_file then
      table.insert(current_lines, line)
    end
  end

  if current_file then file_diffs[current_file] = table.concat(current_lines, '\n') end
  return file_diffs
end

function M._open_pr_review(pr_number, pr_title, repo_slug)
  async_utils.run(string.format('gh pr diff %d', pr_number), function(stdout)
    local file_diffs = parse_diff_by_file(stdout)

    local files = {}
    for filename in pairs(file_diffs) do
      table.insert(files, filename)
    end
    table.sort(files)

    if #files == 0 then
      vim.notify('No changed files in PR #' .. pr_number, vim.log.levels.INFO)
      return
    end

    local file_items = {}
    for i, filename in ipairs(files) do
      table.insert(file_items, {
        idx = i,
        text = filename,
        filename = filename,
        pr_number = pr_number,
      })
    end

    local snacks_ok, snacks = pcall(require, 'snacks')
    if not snacks_ok then return end

    snacks.picker({
      title = string.format('PR #%d: %s (%d files)', pr_number, pr_title, #files),
      items = file_items,
      preview = function(ctx)
        local diff = file_diffs[ctx.item.filename] or 'No diff available'
        local lines = vim.split(diff, '\n')
        vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, lines)
        vim.bo[ctx.buf].filetype = 'diff'
      end,
      format = function(item) return { { item.text, 'Normal' } } end,
      confirm = function(picker, item)
        picker:close()
        M._show_pr_file_diff(pr_number, item.filename, file_diffs[item.filename])
      end,
      actions = {
        approve = function(p)
          p:close()
          M._submit_pr_review(pr_number, 'approve')
        end,
        request_changes = function(p)
          p:close()
          M._submit_pr_review(pr_number, 'request-changes')
        end,
        comment_review = function(p)
          p:close()
          M._submit_pr_review(pr_number, 'comment')
        end,
        open_in_browser = function(p)
          p:close()
          if repo_slug ~= '' then file_utils.open(string.format('https://github.com/%s/pull/%d', repo_slug, pr_number)) end
        end,
      },
      win = {
        input = {
          keys = {
            ['<C-a>'] = { 'approve', desc = 'Approve PR', mode = { 'n', 'i' } },
            ['<C-x>'] = { 'request_changes', desc = 'Request changes', mode = { 'n', 'i' } },
            ['<C-r>'] = { 'comment_review', desc = 'Comment review', mode = { 'n', 'i' } },
            ['<C-o>'] = { 'open_in_browser', desc = 'Open in browser', mode = { 'n', 'i' } },
          },
        },
      },
    })
  end, function(_, err) vim.notify('Failed to get PR diff: ' .. err, vim.log.levels.ERROR) end)
end

function M._show_pr_file_diff(pr_number, filename, diff_content)
  local buf = vim.api.nvim_create_buf(false, true)
  local lines = {}
  for line in (diff_content .. '\n'):gmatch('([^\n]*)\n') do
    table.insert(lines, line)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].filetype = 'diff'
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].modifiable = false
  pcall(vim.api.nvim_buf_set_name, buf, string.format('PR #%d: %s', pr_number, filename))
  vim.api.nvim_set_current_buf(buf)
end

function M._submit_pr_review(pr_number, review_type)
  vim.ui.input({ prompt = 'Review comment (optional): ' }, function(body)
    local cmd = { 'gh', 'pr', 'review', tostring(pr_number), '--' .. review_type }
    if body and body ~= '' then
      table.insert(cmd, '--body')
      table.insert(cmd, body)
    end

    vim.system(
      cmd,
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 then
          local action_labels = { approve = 'Approved', ['request-changes'] = 'Requested changes on', comment = 'Commented on' }
          vim.notify(string.format('%s PR #%d', action_labels[review_type] or 'Reviewed', pr_number), vim.log.levels.INFO)
        else
          vim.notify('Failed to submit review: ' .. (result.stderr or result.stdout or ''), vim.log.levels.ERROR)
        end
      end)
    )
  end)
end

function M.show_current_branch_pr_diff()
  local repo_info = github_utils.get_repo_info()
  local repo_slug = repo_info and repo_info.nameWithOwner or ''

  vim.system(
    { 'gh', 'pr', 'view', '--json', 'number,title' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify('No PR found for current branch', vim.log.levels.WARN)
        return
      end

      local ok, pr = pcall(vim.json.decode, result.stdout)
      if not ok or not pr or not pr.number then
        vim.notify('Could not parse PR info', vim.log.levels.ERROR)
        return
      end

      M._open_pr_review(pr.number, pr.title, repo_slug)
    end)
  )
end

return M
