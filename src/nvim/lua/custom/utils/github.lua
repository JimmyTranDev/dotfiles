local M = {}

--- Format a GitHub PR reviewDecision into an emoji indicator.
---@param decision string|nil one of APPROVED, CHANGES_REQUESTED, REVIEW_REQUIRED, or empty
---@return string emoji
function M.format_review_decision(decision)
  local emojis = {
    APPROVED = '✅',
    CHANGES_REQUESTED = '❌',
    REVIEW_REQUIRED = '⏳',
  }
  if not decision or decision == '' then
    return '⏳'
  end
  return emojis[decision] or '⏳'
end

--- Format a PR draft flag into an emoji indicator.
---@param is_draft boolean|nil true when the PR is a draft, falsy when open
---@return string emoji
function M.format_draft_state(is_draft)
  if is_draft then
    return '📝'
  end
  return '🟢'
end

function M.get_pulls(repo)
  local result = vim.fn.system({ 'gh', 'pr', 'list', '--repo', repo, '--json', 'number,title,url,state' })
  if vim.v.shell_error ~= 0 then return {} end
  local ok, json = pcall(vim.json.decode, result)
  if not ok or not json then return {} end
  return json
end

function M.get_repo_info()
  local output = vim.fn.system('gh repo view --json name,owner,nameWithOwner,url 2>/dev/null')
  if vim.v.shell_error ~= 0 then return nil end
  local ok, repo_info = pcall(vim.json.decode, output)
  return ok and repo_info or nil
end

function M.get_repo_name()
  local info = M.get_repo_info()
  return info and info.name or nil
end

function M.get_github_owners()
  local orgs = {
    vim.env.ORG_GITHUB_NAME,
    vim.env.PRI_GITHUB_USERNAME,
  }

  local valid = {}
  for _, org in ipairs(orgs) do
    if org and org ~= '' then table.insert(valid, org) end
  end

  return valid
end

local cached_login = nil

--- Resolve the current authenticated GitHub login, cached after first lookup.
---@param callback fun(login: string|nil)
function M.get_current_login(callback)
  if cached_login then
    callback(cached_login)
    return
  end

  vim.system(
    { 'gh', 'api', 'user', '--jq', '.login' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 and result.stdout and result.stdout ~= '' then
        cached_login = vim.trim(result.stdout)
      end
      callback(cached_login)
    end)
  )
end

function M.fetch_my_prs_across_owners(owners, opts, callback)
  if #owners == 0 then
    callback({})
    return
  end

  opts = opts or {}
  local extra_args = opts.extra_args or {}

  local all_prs = {}
  local pending = #owners

  for _, owner in ipairs(owners) do
    local cmd = { 'gh', 'search', 'prs' }
    for _, arg in ipairs(extra_args) do
      table.insert(cmd, arg)
    end
    vim.list_extend(cmd, {
      '--owner',
      owner,
      '--state',
      'open',
      '--author',
      '@me',
      '--json',
      'number,title,repository,url,isDraft,createdAt',
      '--limit',
      '100',
    })

    vim.system(
      cmd,
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 and result.stdout and result.stdout ~= '' then
          local ok, prs = pcall(vim.json.decode, result.stdout)
          if ok and type(prs) == 'table' then
            for _, pr in ipairs(prs) do
              local repo_name = pr.repository and pr.repository.nameWithOwner or ''
              table.insert(all_prs, {
                text = string.format('#%d %s [%s]', pr.number, pr.title, repo_name),
                number = pr.number,
                title = pr.title,
                url = pr.url,
                repo = repo_name,
                draft = pr.isDraft,
                created_at = pr.createdAt,
              })
            end
          end
        end

        pending = pending - 1
        if pending == 0 then callback(all_prs) end
      end)
    )
  end
end

--- Enrich a list of PR items with their review decision, rebuilding each item's
--- `text` to include a leading draft/open emoji followed by an approval emoji
--- right after the username (or at the start when there is no username).
--- `gh search prs` cannot return reviewDecision, so it is fetched per PR here.
---@param prs table[] items with `repo`, `number`, `title`, optional `author`, optional `draft`
---@param callback fun(prs: table[])
function M.append_review_decisions(prs, callback)
  if #prs == 0 then
    callback(prs)
    return
  end

  local function apply(pr, decision)
    pr.review_decision = decision
    local emoji = M.format_review_decision(decision)
    local draft_emoji = M.format_draft_state(pr.draft)
    if pr.author then
      pr.text = string.format('%s [%s] %s #%d %s [%s]', draft_emoji, pr.author, emoji, pr.number, pr.title, pr.repo)
    else
      pr.text = string.format('%s %s #%d %s [%s]', draft_emoji, emoji, pr.number, pr.title, pr.repo)
    end
  end

  local pending = #prs

  for _, pr in ipairs(prs) do
    if not pr.repo or pr.repo == '' or not pr.number then
      apply(pr, nil)
      pending = pending - 1
      if pending == 0 then callback(prs) end
    else
      vim.system(
        { 'gh', 'pr', 'view', tostring(pr.number), '--repo', pr.repo, '--json', 'reviewDecision' },
        { text = true },
        vim.schedule_wrap(function(result)
          local decision = nil
          if result.code == 0 and result.stdout and result.stdout ~= '' then
            local ok, data = pcall(vim.json.decode, result.stdout)
            if ok and type(data) == 'table' then decision = data.reviewDecision end
          end
          apply(pr, decision)
          pending = pending - 1
          if pending == 0 then callback(prs) end
        end)
      )
    end
  end
end

function M.get_pr_file_stats(repo, pr_number, callback)
  local api_path = string.format('/repos/%s/pulls/%d/files', repo, pr_number)

  vim.system(
    { 'gh', 'api', api_path, '--paginate', '--jq', '[.[] | {filename, additions, deletions}]' },
    { text = true },
    vim.schedule_wrap(function(result)
      local additions = 0
      local deletions = 0
      if result.code == 0 then
        local ok, files = pcall(vim.json.decode, result.stdout)
        if ok and files then
          for _, file in ipairs(files) do
            if file.filename ~= 'pnpm-lock.yaml' then
              additions = additions + (file.additions or 0)
              deletions = deletions + (file.deletions or 0)
            end
          end
        end
      end
      callback(additions, deletions)
    end)
  )
end

return M
