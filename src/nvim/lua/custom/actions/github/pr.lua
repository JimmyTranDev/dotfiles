local github_utils = require('custom.utils.github')
local file_utils = require('custom.utils.files')

local M = {}

local function format_pr_display(pr) return string.format('#%d %s [%s]', pr.number, pr.title, pr.state) end

local function select_and_open_pr_from_list(pulls, context_name)
  if #pulls == 0 then
    vim.notify('No PRs found in ' .. context_name, vim.log.levels.INFO)
    return
  end

  local pr_options = {}
  for _, pr in ipairs(pulls) do
    table.insert(pr_options, format_pr_display(pr))
  end

  vim.ui.select(pr_options, {
    prompt = 'Select PR to open:',
  }, function(selected_display)
    if not selected_display then return end

    for _, pr in ipairs(pulls) do
      if selected_display:find('#' .. pr.number) then
        file_utils.open(pr.url)
        vim.notify('Opened PR #' .. pr.number .. ' in browser', vim.log.levels.INFO)
        return
      end
    end
  end)
end

function M.create_draft_pr()
  local result = vim.fn.system('gh pr create --draft --web 2>&1')

  if vim.v.shell_error == 0 then
    vim.notify('Draft PR created and opened in browser', vim.log.levels.INFO)
  else
    vim.notify('Failed to create draft PR: ' .. result, vim.log.levels.ERROR)
  end
end

function M.open_current_repo_prs()
  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.owner or not repo_info.name then
    vim.notify('Could not determine current repository', vim.log.levels.ERROR)
    return
  end

  local repo_full = repo_info.owner.login .. '/' .. repo_info.name
  local pulls = github_utils.get_pulls(repo_full)

  select_and_open_pr_from_list(pulls, repo_full)
end

function M.select_and_open_pr()
  local valid_orgs = github_utils.get_github_owners()

  if #valid_orgs == 0 then
    vim.notify('No GitHub organizations configured in environment', vim.log.levels.ERROR)
    return
  end

  vim.ui.select(valid_orgs, {
    prompt = 'Select organization:',
  }, function(selected_org)
    if not selected_org then return end

    M.select_repo_and_open_pr(selected_org)
  end)
end

function M.select_repo_and_open_pr(org_name)
  local result = vim.fn.system({ 'gh', 'repo', 'list', org_name, '--limit', '30', '--json', 'name,url' })
  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to fetch repositories for ' .. org_name, vim.log.levels.ERROR)
    return
  end

  local ok, repos = pcall(vim.json.decode, result)
  if not ok or #repos == 0 then
    vim.notify('No repositories found for ' .. org_name, vim.log.levels.ERROR)
    return
  end

  local repo_names = {}
  for _, repo in ipairs(repos) do
    table.insert(repo_names, repo.name)
  end

  vim.ui.select(repo_names, {
    prompt = 'Select repository:',
  }, function(selected_repo)
    if not selected_repo then return end

    local pulls = github_utils.get_pulls(org_name .. '/' .. selected_repo)
    select_and_open_pr_from_list(pulls, selected_repo)
  end)
end

function M.open_current_repo_in_browser()
  local remote_url = vim.fn.system('git remote get-url origin 2>/dev/null'):gsub('%s+$', '')
  if vim.v.shell_error ~= 0 or remote_url == '' then
    vim.notify('No git remote found', vim.log.levels.WARN)
    return
  end

  local org, repo = remote_url:match('github%.com[:/]([^/]+)/([^/%.]+)')
  if not org or not repo then
    vim.notify('Could not parse GitHub URL from: ' .. remote_url, vim.log.levels.WARN)
    return
  end

  local url = string.format('https://github.com/%s/%s', org, repo)
  file_utils.open(url)
  vim.notify('Opened ' .. org .. '/' .. repo, vim.log.levels.INFO)
end

function M.open_current_commit_in_github()
  local commit_hash = vim.fn.system('git rev-parse HEAD 2>/dev/null'):gsub('%s+', '')
  if vim.v.shell_error ~= 0 or not commit_hash or commit_hash == '' then
    vim.notify('Could not determine current commit hash', vim.log.levels.ERROR)
    return
  end

  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.nameWithOwner then
    vim.notify('Could not determine repository', vim.log.levels.ERROR)
    return
  end

  local github_url = string.format('https://github.com/%s/commit/%s', repo_info.nameWithOwner, commit_hash)

  file_utils.open(github_url)
  vim.notify(string.format('Opened commit %s in GitHub', commit_hash:sub(1, 7)), vim.log.levels.INFO)
end

function M.copy_open_prs()
  local org_name = vim.env.ORG_GITHUB_NAME
  if not org_name or org_name == '' then
    vim.notify('ORG_GITHUB_NAME not set', vim.log.levels.ERROR)
    return
  end

  vim.notify('Fetching open PRs for ' .. org_name .. '...', vim.log.levels.INFO)

  vim.system(
    {
      'gh',
      'search',
      'prs',
      'draft:false',
      '--owner',
      org_name,
      '--state',
      'open',
      '--author',
      '@me',
      '--json',
      'number,title,repository,url',
      '--limit',
      '100',
    },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify('Failed to fetch PRs: ' .. (result.stderr or result.stdout), vim.log.levels.ERROR)
        return
      end

      local ok, prs = pcall(vim.json.decode, result.stdout)
      if not ok or not prs or #prs == 0 then
        vim.notify('No open PRs found', vim.log.levels.INFO)
        return
      end

      local pending = #prs
      local pr_data = {}

      for i, pr in ipairs(prs) do
        local repo_full = pr.repository and pr.repository.nameWithOwner or ''

        github_utils.get_pr_file_stats(repo_full, pr.number, function(additions, deletions)
          pr_data[i] = string.format('%s %s +%d -%d', pr.url, pr.title, additions, deletions)
          pending = pending - 1

          if pending == 0 then
            local lines = {}
            for j = 1, #prs do
              table.insert(lines, pr_data[j])
            end
            local formatted = table.concat(lines, '\n')
            vim.fn.setreg('+', formatted)
            vim.notify(string.format('Copied %d PR(s) to clipboard', #prs), vim.log.levels.INFO)
          end
        end)
      end
    end)
  )
end

function M.select_and_copy_pr()
  local valid_owners = github_utils.get_github_owners()

  if #valid_owners == 0 then
    vim.notify('No GitHub organizations configured in environment', vim.log.levels.ERROR)
    return
  end

  github_utils.fetch_my_prs_across_owners(valid_owners, { extra_args = { 'draft:false' } }, function(all_prs)
    if #all_prs == 0 then
      vim.notify('No open PRs found', vim.log.levels.INFO)
      return
    end

    table.sort(all_prs, function(a, b) return a.repo < b.repo end)

    local snacks_ok, snacks = pcall(require, 'snacks')
    if not snacks_ok then return end

    snacks.picker({
      title = 'Select PR to Copy',
      items = all_prs,
      format = function(item) return { { item.text, 'Normal' } } end,
      confirm = function(picker, item)
        picker:close()
        github_utils.get_pr_file_stats(item.repo, item.number, function(additions, deletions)
          local formatted = string.format('%s %s +%d -%d', item.url, item.title, additions, deletions)
          vim.fn.setreg('+', formatted)
          vim.notify(string.format('Copied PR #%d to clipboard', item.number), vim.log.levels.INFO)
        end)
      end,
    })
  end)
end

return M
