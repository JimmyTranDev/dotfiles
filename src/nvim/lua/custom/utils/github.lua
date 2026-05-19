local M = {}

function M.get_pulls(repo)
  local result = vim.fn.system({ 'gh', 'pr', 'list', '--repo', repo, '--json', 'number,title,url,state' })
  if vim.v.shell_error ~= 0 then return {} end
  local ok, json = pcall(vim.fn.json_decode, result)
  if not ok or not json then return {} end
  return json
end

function M.get_repo_info()
  local output = vim.fn.system('gh repo view --json name,owner,nameWithOwner,url 2>/dev/null')
  if vim.v.shell_error ~= 0 then return nil end
  local ok, repo_info = pcall(vim.fn.json_decode, output)
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
      'number,title,repository,url',
      '--limit',
      '100',
    })

    vim.system(
      cmd,
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 and result.stdout and result.stdout ~= '' then
          local ok, prs = pcall(vim.fn.json_decode, result.stdout)
          if ok and type(prs) == 'table' then
            for _, pr in ipairs(prs) do
              local repo_name = pr.repository and pr.repository.nameWithOwner or ''
              table.insert(all_prs, {
                text = string.format('#%d %s [%s]', pr.number, pr.title, repo_name),
                number = pr.number,
                title = pr.title,
                url = pr.url,
                repo = repo_name,
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

function M.get_pr_file_stats(repo, pr_number, callback)
  local api_path = string.format('/repos/%s/pulls/%d/files', repo, pr_number)

  vim.system(
    { 'gh', 'api', api_path, '--paginate', '--jq', '[.[] | {filename, additions, deletions}]' },
    { text = true },
    vim.schedule_wrap(function(result)
      local additions = 0
      local deletions = 0
      if result.code == 0 then
        local ok, files = pcall(vim.fn.json_decode, result.stdout)
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
