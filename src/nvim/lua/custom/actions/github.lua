local github_utils = require('custom.utils.github')
local file_utils = require('custom.utils.files')
local async_utils = require('custom.utils.async')
local frequency_cache = require('custom.utils.frequency_cache')

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

  local ok, repos = pcall(vim.fn.json_decode, result)
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

      local ok, prs = pcall(vim.fn.json_decode, result.stdout)
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

function M.select_own_open_prs()
  local valid_owners = github_utils.get_github_owners()

  if #valid_owners == 0 then
    vim.notify('No GitHub organizations configured in environment', vim.log.levels.ERROR)
    return
  end

  github_utils.fetch_my_prs_across_owners(valid_owners, {}, function(all_prs)
    if #all_prs == 0 then
      vim.notify('No open PRs found', vim.log.levels.INFO)
      return
    end

    table.sort(all_prs, function(a, b) return a.repo < b.repo end)

    local snacks_ok, snacks = pcall(require, 'snacks')
    if not snacks_ok then return end

    snacks.picker({
      title = 'My Open PRs',
      items = all_prs,
      format = function(item) return { { item.text, 'Normal' } } end,
      confirm = function(picker, item)
        picker:close()
        file_utils.open(item.url)
        vim.notify('Opened PR #' .. item.number .. ' in browser', vim.log.levels.INFO)
      end,
    })
  end)
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

function M.select_org_repo_and_create_issue()
  local valid_orgs = github_utils.get_github_owners()

  if #valid_orgs == 0 then
    vim.notify('No GitHub organizations configured in environment', vim.log.levels.ERROR)
    return
  end

  vim.ui.select(valid_orgs, {
    prompt = 'Select organization:',
  }, function(selected_org)
    if not selected_org then return end

    vim.system(
      { 'gh', 'repo', 'list', selected_org, '--limit', '30', '--json', 'name,url' },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          vim.notify('Failed to fetch repositories for ' .. selected_org, vim.log.levels.ERROR)
          return
        end

        local ok, repos = pcall(vim.fn.json_decode, result.stdout)
        if not ok or type(repos) ~= 'table' or #repos == 0 then
          vim.notify('No repositories found for ' .. selected_org, vim.log.levels.ERROR)
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

          vim.ui.input({
            prompt = 'Issue title: ',
          }, function(title)
            if not title or title == '' then return end

            vim.system(
              { 'gh', 'issue', 'create', '--repo', selected_org .. '/' .. selected_repo, '--title', title, '--web' },
              { text = true },
              vim.schedule_wrap(function(issue_result)
                if issue_result.code == 0 then
                  vim.notify('Issue creation opened in browser', vim.log.levels.INFO)
                else
                  vim.notify('Failed to create issue: ' .. (issue_result.stderr or issue_result.stdout), vim.log.levels.ERROR)
                end
              end)
            )
          end)
        end)
      end)
    )
  end)
end

local cached_team_members = {}

---@return string[]|nil team_slugs
---@return string|nil org_name
local function parse_team_config()
  local teams_str = vim.env.GITHUB_PR_FILTER_TEAMS
  if not teams_str or teams_str == '' then
    vim.notify('GITHUB_PR_FILTER_TEAMS not set (comma-separated team slugs)', vim.log.levels.ERROR)
    return nil, nil
  end

  local org_name = vim.env.ORG_GITHUB_NAME
  if not org_name or org_name == '' then
    vim.notify('ORG_GITHUB_NAME not set', vim.log.levels.ERROR)
    return nil, nil
  end

  local team_slugs = {}
  for slug in teams_str:gmatch('[^,]+') do
    local trimmed = slug:match('^%s*(.-)%s*$')
    if trimmed ~= '' then
      table.insert(team_slugs, trimmed)
    end
  end

  if #team_slugs == 0 then
    vim.notify('No teams found in GITHUB_PR_FILTER_TEAMS', vim.log.levels.ERROR)
    return nil, nil
  end

  return team_slugs, org_name
end

local function fetch_team_members_for_slug(org_name, team_slug, callback)
  vim.system(
    { 'gh', 'api', '/orgs/' .. org_name .. '/teams/' .. team_slug .. '/members', '--jq', '.[].login' },
    { text = true },
    vim.schedule_wrap(function(members_result)
      local members = {}
      if members_result.code == 0 and members_result.stdout and members_result.stdout ~= '' then
        for login in members_result.stdout:gmatch('[^\n]+') do
          local trimmed = login:match('^%s*(.-)%s*$')
          if trimmed ~= '' then table.insert(members, trimmed) end
        end
      end
      cached_team_members[team_slug] = members
      callback(members)
    end)
  )
end

local function get_team_members_for_slugs(org_name, team_slugs, callback)
  local all_usernames = {}
  local seen = {}
  local pending = #team_slugs

  for _, slug in ipairs(team_slugs) do
    if cached_team_members[slug] then
      for _, login in ipairs(cached_team_members[slug]) do
        if not seen[login] then
          seen[login] = true
          table.insert(all_usernames, login)
        end
      end
      pending = pending - 1
      if pending == 0 then callback(all_usernames) end
    else
      fetch_team_members_for_slug(org_name, slug, function(members)
        for _, login in ipairs(members) do
          if not seen[login] then
            seen[login] = true
            table.insert(all_usernames, login)
          end
        end
        pending = pending - 1
        if pending == 0 then callback(all_usernames) end
      end)
    end
  end
end

function M.refresh_team_members_cache()
  local teams_str = vim.env.GITHUB_PR_FILTER_TEAMS
  if not teams_str or teams_str == '' then
    vim.notify('GITHUB_PR_FILTER_TEAMS not set', vim.log.levels.ERROR)
    return
  end

  local org_name = vim.env.ORG_GITHUB_NAME
  if not org_name or org_name == '' then
    vim.notify('ORG_GITHUB_NAME not set', vim.log.levels.ERROR)
    return
  end

  local team_slugs = {}
  for slug in teams_str:gmatch('[^,]+') do
    local trimmed = slug:match('^%s*(.-)%s*$')
    if trimmed ~= '' then table.insert(team_slugs, trimmed) end
  end

  cached_team_members = {}
  vim.notify('Refreshing team members cache...', vim.log.levels.INFO)
  get_team_members_for_slugs(org_name, team_slugs, function(members)
    vim.notify('Cached ' .. #members .. ' team members', vim.log.levels.INFO)
  end)
end

local function fetch_and_show_prs(org_name, usernames)
  if #usernames == 0 then
    vim.notify('No members found', vim.log.levels.ERROR)
    return
  end

  vim.notify('Fetching open PRs for ' .. #usernames .. ' team members...', vim.log.levels.INFO)

  local all_prs = {}
  local pending = #usernames

  for _, username in ipairs(usernames) do
    vim.system(
      {
        'gh',
        'search',
        'prs',
        '--owner',
        org_name,
        '--state',
        'open',
        '--author',
        username,
        '--json',
        'number,title,repository,url',
        '--limit',
        '100',
      },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 and result.stdout and result.stdout ~= '' then
          local ok, prs = pcall(vim.fn.json_decode, result.stdout)
          if ok and type(prs) == 'table' then
            for _, pr in ipairs(prs) do
              local repo_name = pr.repository and pr.repository.nameWithOwner or ''
              table.insert(all_prs, {
                text = string.format('[%s] #%d %s [%s]', username, pr.number, pr.title, repo_name),
                number = pr.number,
                title = pr.title,
                url = pr.url,
                repo = repo_name,
                author = username,
              })
            end
          end
        end

        pending = pending - 1
        if pending > 0 then return end

        if #all_prs == 0 then
          vim.notify('No open PRs found for team members', vim.log.levels.INFO)
          return
        end

        table.sort(all_prs, function(a, b)
          if a.author ~= b.author then return a.author < b.author end
          return a.repo < b.repo
        end)

        local snacks_ok, snacks = pcall(require, 'snacks')
        if not snacks_ok then return end

        snacks.picker({
          title = 'Open PRs by People',
          items = all_prs,
          format = function(item) return { { item.text, 'Normal' } } end,
          confirm = function(picker, item)
            picker:close()
            file_utils.open(item.url)
            vim.notify('Opened PR #' .. item.number .. ' in browser', vim.log.levels.INFO)
          end,
        })
      end)
    )
  end
end

function M.select_open_prs_by_people()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then
    return
  end

  local choices = {}
  for _, slug in ipairs(team_slugs) do
    table.insert(choices, { text = slug, slugs = { slug } })
  end
  table.insert(choices, { text = 'All teams', slugs = team_slugs })

  vim.ui.select(choices, {
    prompt = 'Select team:',
    format_item = function(item) return item.text end,
  }, function(choice)
    if not choice then
      return
    end
    get_team_members_for_slugs(org_name, choice.slugs, function(usernames)
      fetch_and_show_prs(org_name, usernames)
    end)
  end)
end

function M.select_open_prs_by_default_team()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then
    return
  end

  get_team_members_for_slugs(org_name, { team_slugs[1] }, function(usernames)
    fetch_and_show_prs(org_name, usernames)
  end)
end

function M.list_org_repos_and_open()
  local programming_dir = vim.fn.expand('~/Programming')
  local org_handle = vim.uv.fs_scandir(programming_dir)
  if not org_handle then
    vim.notify('Could not scan ~/Programming', vim.log.levels.ERROR)
    return
  end

  local items = {}

  while true do
    local org_name, org_type = vim.uv.fs_scandir_next(org_handle)
    if not org_name then break end
    if org_type ~= 'directory' or org_name == 'Worktrees' or org_name == 'wcreated' or org_name == 'wcheckout' then goto continue_org end

    local repo_handle = vim.uv.fs_scandir(programming_dir .. '/' .. org_name)
    if not repo_handle then goto continue_org end

    while true do
      local repo_name, repo_type = vim.uv.fs_scandir_next(repo_handle)
      if not repo_name then break end
      if repo_type == 'directory' then
        table.insert(items, {
          text = '[' .. org_name .. '] ' .. repo_name,
          name = repo_name,
          url = 'https://github.com/' .. org_name .. '/' .. repo_name,
          org = org_name,
        })
      end
    end

    ::continue_org::
  end

  table.sort(items, function(a, b) return a.text < b.text end)

  frequency_cache.sort_by_frequency('org_repos', items, function(item) return item.org .. '/' .. item.name end)

  -- Move current repo to the top
  local cwd = vim.fn.getcwd()
  local cwd_org = vim.fn.fnamemodify(cwd, ':h:t')
  local cwd_repo = vim.fn.fnamemodify(cwd, ':t')
  for i, item in ipairs(items) do
    if item.org == cwd_org and item.name == cwd_repo then
      table.remove(items, i)
      table.insert(items, 1, item)
      break
    end
  end

  if #items == 0 then
    vim.notify('No repositories found in ~/Programming', vim.log.levels.ERROR)
    return
  end

  local snacks_ok, snacks = pcall(require, 'snacks')
  if not snacks_ok then return end

  snacks.picker({
    title = 'Repos',
    items = items,
    format = function(item) return { { item.text, 'Normal' } } end,
    confirm = function(picker, item)
      picker:close()
      frequency_cache.record('org_repos', item.org .. '/' .. item.name)
      file_utils.open(item.url)
      vim.notify('Opened ' .. item.name .. ' in browser', vim.log.levels.INFO)
    end,
  })
end

function M.pr_review_mode()
  local repo_info = github_utils.get_repo_info()
  local repo_slug = repo_info and repo_info.nameWithOwner or ''

  async_utils.run('gh pr list --json number,title,headRefName,author --limit 20', function(stdout)
    local ok, prs = pcall(vim.fn.json_decode, stdout)
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

function M.copy_github_line_url()
  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.nameWithOwner then
    vim.notify('Could not determine repository', vim.log.levels.ERROR)
    return
  end

  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end

  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 or not git_root then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end

  local relative_path = file:sub(#git_root + 2)

  local commit_hash = vim.fn.systemlist('git rev-parse HEAD')[1]
  if vim.v.shell_error ~= 0 or not commit_hash then
    vim.notify('Could not determine commit hash', vim.log.levels.ERROR)
    return
  end

  local mode = vim.fn.mode()
  local line_fragment
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local start_line = vim.fn.line('v')
    local end_line = vim.fn.line('.')
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    if start_line == end_line then
      line_fragment = string.format('#L%d', start_line)
    else
      line_fragment = string.format('#L%d-L%d', start_line, end_line)
    end
  else
    line_fragment = string.format('#L%d', vim.fn.line('.'))
  end

  local url = string.format(
    'https://github.com/%s/blob/%s/%s%s',
    repo_info.nameWithOwner,
    commit_hash,
    relative_path,
    line_fragment
  )

  vim.fn.setreg('+', url)
  vim.notify('Copied: ' .. url, vim.log.levels.INFO)
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

local function show_notifications_picker(notifications, title_suffix)
  local items = {}
  for _, notif in ipairs(notifications) do
    local type_icon = ({ PullRequest = '', Issue = '', Discussion = '󰍩' })[notif.subject_type] or ''
    table.insert(items, {
      text = string.format('%s [%s] %s (%s)', type_icon, notif.repository, notif.subject_title, notif.reason),
      notif = notif,
    })
  end

  local snacks_ok, snacks = pcall(require, 'snacks')
  if not snacks_ok then return end

  local title = 'GitHub Notifications (' .. #items .. ')'
  if title_suffix then
    title = title .. ' - ' .. title_suffix
  end

      -- Cache for fetched notification details (keyed by subject_url)
      local detail_cache = {}

      snacks.picker({
        title = 'GitHub Notifications (' .. #items .. ')',
        items = items,
        format = function(item) return { { item.text, 'Normal' } } end,
        preview = function(ctx)
          local item = ctx.item
          if not item or not item.notif then return end
          local notif = item.notif

          local function render_preview(lines)
            ctx.preview:set_lines(lines)

            -- Highlight header lines
            for i, line in ipairs(lines) do
              if line:match('^[A-Z].*:') and not line:match('^  ') then
                ctx.preview:highlight({ col = 0, line = i, end_col = line:find(':'), hl = 'Title' })
              elseif line:match('^─') then
                ctx.preview:highlight({ col = 0, line = i, end_col = #line, hl = 'Comment' })
              end
            end
          end

          -- Build static header
          local reason_labels = {
            assign = 'Assigned to you',
            author = 'You created this',
            comment = 'New comment',
            ci_activity = 'CI activity',
            invitation = 'Invitation',
            manual = 'Subscribed manually',
            mention = 'You were mentioned',
            review_requested = 'Review requested',
            security_alert = 'Security alert',
            state_change = 'State changed',
            subscribed = 'Subscribed',
            team_mention = 'Team mentioned',
          }

          local header = {
            'Title:      ' .. (notif.subject_title or ''),
            'Repository: ' .. (notif.repository or ''),
            'Type:       ' .. (notif.subject_type or ''),
            'Reason:     ' .. (reason_labels[notif.reason] or notif.reason or ''),
            'Updated:    ' .. (notif.updated_at or ''),
            'Unread:     ' .. (notif.unread and 'Yes' or 'No'),
            '────────────────────────────────────────',
          }

          -- Show header immediately, then fetch details async
          local api_url = notif.subject_url
          if not api_url or api_url == '' then
            render_preview(header)
            return
          end

          if detail_cache[api_url] then
            local lines = vim.list_extend({}, header)
            vim.list_extend(lines, detail_cache[api_url])
            render_preview(lines)
            return
          end

          -- Show header with loading indicator
          local loading = vim.list_extend({}, header)
          table.insert(loading, 'Loading details...')
          render_preview(loading)

          -- Fetch body/details from the API
          local jq_expr = notif.subject_type == 'PullRequest'
            and '{state: .state, user: .user.login, body: .body, additions: .additions, deletions: .deletions, changed_files: .changed_files, merged: .merged, draft: .draft, labels: [.labels[].name]}'
            or '{state: .state, user: .user.login, body: .body, labels: [.labels[].name]}'

          vim.system(
            { 'gh', 'api', api_url, '--jq', jq_expr },
            { text = true },
            vim.schedule_wrap(function(detail_result)
              if detail_result.code ~= 0 or not detail_result.stdout or detail_result.stdout == '' then
                detail_cache[api_url] = { '(Could not load details)' }
              else
                local ok, detail = pcall(vim.fn.json_decode, detail_result.stdout)
                if not ok or not detail then
                  detail_cache[api_url] = { '(Failed to parse details)' }
                else
                  local detail_lines = {}
                  if detail.user then
                    table.insert(detail_lines, 'Author:     ' .. detail.user)
                  end
                  if detail.state then
                    local state = detail.state
                    if detail.merged then
                      state = 'merged'
                    elseif detail.draft then
                      state = 'draft'
                    end
                    table.insert(detail_lines, 'State:      ' .. state)
                  end
                  if detail.additions then
                    table.insert(
                      detail_lines,
                      'Changes:    +' .. detail.additions .. ' -' .. detail.deletions .. ' (' .. detail.changed_files .. ' files)'
                    )
                  end
                  if detail.labels and #detail.labels > 0 then
                    table.insert(detail_lines, 'Labels:     ' .. table.concat(detail.labels, ', '))
                  end
                  if detail.body and detail.body ~= '' then
                    table.insert(detail_lines, '────────────────────────────────────────')
                    for body_line in detail.body:gmatch('[^\r\n]*') do
                      table.insert(detail_lines, body_line)
                    end
                  end
                  detail_cache[api_url] = detail_lines
                end
              end

              -- Re-render if this item is still selected
              local lines = vim.list_extend({}, header)
              vim.list_extend(lines, detail_cache[api_url])
              render_preview(lines)
            end)
          )
        end,
        confirm = function(picker, item)
          picker:close()
          local api_url = item.notif.subject_url
          if not api_url or api_url == '' then return end

          vim.system(
            { 'gh', 'api', api_url, '--jq', '.html_url' },
            { text = true },
            vim.schedule_wrap(function(url_result)
              if url_result.code == 0 and url_result.stdout and url_result.stdout ~= '' then
                local html_url = vim.trim(url_result.stdout)
                file_utils.open(html_url)
              else
                vim.notify('Could not resolve URL for notification', vim.log.levels.WARN)
              end
            end)
          )
        end,
        actions = {
          mark_read = function(p)
            local item = p:current()
            if not item or not item.notif then return end
            vim.system(
              { 'gh', 'api', '--method', 'PATCH', '/notifications/threads/' .. item.notif.id },
              { text = true },
              vim.schedule_wrap(function(mark_result)
                if mark_result.code == 0 then
                  vim.notify('Marked as read: ' .. item.notif.subject_title, vim.log.levels.INFO)
                end
              end)
            )
          end,
        },
        win = {
          input = {
            keys = {
              ['<C-d>'] = { 'mark_read', desc = 'Mark as read', mode = { 'n', 'i' } },
            },
          },
        },
      })
end

local function fetch_notifications(callback)
  vim.notify('Fetching GitHub notifications...', vim.log.levels.INFO)
  vim.system(
    {
      'gh',
      'api',
      'notifications',
      '--jq',
      '.[] | {id: .id, subject_title: .subject.title, subject_type: .subject.type, subject_url: .subject.url, repository: .repository.full_name, reason: .reason, updated_at: .updated_at, unread: .unread}',
    },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify('Failed to fetch notifications: ' .. (result.stderr or ''), vim.log.levels.ERROR)
        return
      end

      if not result.stdout or result.stdout == '' then
        vim.notify('No notifications', vim.log.levels.INFO)
        return
      end

      local notifications = {}
      for line in result.stdout:gmatch('[^\n]+') do
        local ok, notif = pcall(vim.fn.json_decode, line)
        if ok and notif then
          table.insert(notifications, notif)
        end
      end

      if #notifications == 0 then
        vim.notify('No notifications', vim.log.levels.INFO)
        return
      end

      callback(notifications)
    end)
  )
end

function M.show_notifications()
  fetch_notifications(function(notifications)
    show_notifications_picker(notifications, nil)
  end)
end

---@param org_name string
---@param slugs string[]
---@param label string
local function fetch_notifications_for_team(org_name, slugs, label)
  get_team_members_for_slugs(org_name, slugs, function(usernames)
    if #usernames == 0 then
      vim.notify('No members found for selected team', vim.log.levels.WARN)
      return
    end

    local members_set = {}
    for _, login in ipairs(usernames) do
      members_set[login:lower()] = true
    end

    fetch_notifications(function(notifications)
      vim.notify('Resolving notification authors...', vim.log.levels.INFO)
      local pending = #notifications
      local author_map = {}

      if pending == 0 then
        vim.notify('No notifications', vim.log.levels.INFO)
        return
      end

      for _, notif in ipairs(notifications) do
        local api_url = notif.subject_url
        if not api_url or api_url == '' then
          pending = pending - 1
          if pending == 0 then
            vim.schedule(function()
              local filtered = {}
              for _, n in ipairs(notifications) do
                local author = author_map[n.subject_url]
                if author and members_set[author:lower()] then
                  table.insert(filtered, n)
                end
              end
              if #filtered == 0 then
                vim.notify('No notifications from team members', vim.log.levels.INFO)
                return
              end
              show_notifications_picker(filtered, label)
            end)
          end
        else
          vim.system(
            { 'gh', 'api', api_url, '--jq', '.user.login' },
            { text = true },
            vim.schedule_wrap(function(author_result)
              if author_result.code == 0 and author_result.stdout and author_result.stdout ~= '' then
                author_map[api_url] = vim.trim(author_result.stdout)
              end
              pending = pending - 1
              if pending == 0 then
                local filtered = {}
                for _, n in ipairs(notifications) do
                  local author = author_map[n.subject_url]
                  if author and members_set[author:lower()] then
                    table.insert(filtered, n)
                  end
                end
                if #filtered == 0 then
                  vim.notify('No notifications from team members', vim.log.levels.INFO)
                  return
                end
                show_notifications_picker(filtered, label)
              end
            end)
          )
        end
      end
    end)
  end)
end

function M.show_notifications_by_team()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then
    return
  end

  local choices = {}
  for _, slug in ipairs(team_slugs) do
    table.insert(choices, { text = slug, slugs = { slug } })
  end
  table.insert(choices, { text = 'All teams', slugs = team_slugs })

  vim.ui.select(choices, {
    prompt = 'Select team:',
    format_item = function(item) return item.text end,
  }, function(choice)
    if not choice then
      return
    end
    fetch_notifications_for_team(org_name, choice.slugs, choice.text)
  end)
end

function M.show_notifications_by_default_team()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then
    return
  end

  fetch_notifications_for_team(org_name, { team_slugs[1] }, team_slugs[1])
end

function M.redeploy_pr()
  vim.system(
    { 'gh', 'pr', 'view', '--json', 'number,comments', '--jq', '.number' },
    { text = true },
    vim.schedule_wrap(function(pr_result)
      if pr_result.code ~= 0 or not pr_result.stdout or pr_result.stdout == '' then
        vim.notify('No PR found for current branch', vim.log.levels.ERROR)
        return
      end

      local pr_number = vim.trim(pr_result.stdout)

      vim.system(
        { 'gh', 'api', string.format('repos/{owner}/{repo}/issues/%s/comments', pr_number), '--jq', '[.[] | select((.body | test("#deploy")) or .user.login == "github-actions[bot]") | {id: .id, author: .user.login}]' },
        { text = true },
        vim.schedule_wrap(function(comments_result)
          if comments_result.code ~= 0 then
            vim.notify('Failed to fetch PR comments', vim.log.levels.ERROR)
            return
          end

          local ok, comments = pcall(vim.fn.json_decode, comments_result.stdout)
          if not ok then
            comments = {}
          end

          local pending = #comments

          local function add_deploy_comment()
            vim.system(
              { 'gh', 'pr', 'comment', pr_number, '--body', '#deploy' },
              { text = true },
              vim.schedule_wrap(function(result)
                if result.code == 0 then
                  vim.notify(string.format('Added #deploy to PR #%s', pr_number), vim.log.levels.INFO)
                else
                  vim.notify('Failed to add #deploy comment', vim.log.levels.ERROR)
                end
              end)
            )
          end

          if pending == 0 then
            add_deploy_comment()
            return
          end

          for _, comment in ipairs(comments) do
            vim.system(
              { 'gh', 'api', '--method', 'DELETE', string.format('repos/{owner}/{repo}/issues/comments/%d', comment.id) },
              { text = true },
              vim.schedule_wrap(function()
                pending = pending - 1
                if pending == 0 then
                  add_deploy_comment()
                end
              end)
            )
          end
        end)
      )
    end)
  )
end

--- Parse a GitHub file URL from the clipboard and open the corresponding local file at the correct line
function M.open_file_from_clipboard_url()
  local clipboard = vim.fn.getreg('+')
  if not clipboard or clipboard == '' then
    vim.notify('Clipboard is empty', vim.log.levels.WARN)
    return
  end

  -- Extract path portion after blob/tree/raw in GitHub-like URLs
  local after_type = clipboard:match('https?://[^/]+/[^/]+/[^/]+/blob/(%S+)')
    or clipboard:match('https?://[^/]+/[^/]+/[^/]+/tree/(%S+)')
    or clipboard:match('https?://[^/]+/[^/]+/[^/]+/raw/(%S+)')

  if not after_type then
    vim.notify('No GitHub file URL found in clipboard', vim.log.levels.WARN)
    return
  end

  -- Split path from fragment (#L42, #L10-L20)
  local path_with_ref, fragment = after_type:match('^(.-)#(.*)$')
  if not path_with_ref then
    path_with_ref = after_type
  end

  -- Strip query parameters
  path_with_ref = path_with_ref:gsub('%?.*', '')

  -- Parse line number from fragment
  local line_num
  if fragment then
    line_num = tonumber(fragment:match('L(%d+)'))
  end

  -- Decode URL-encoded characters (%20, etc.)
  path_with_ref = path_with_ref:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)

  -- Split into segments to handle refs with slashes (e.g. feature/my-branch)
  local segments = {}
  for seg in path_with_ref:gmatch('[^/]+') do
    table.insert(segments, seg)
  end

  if #segments < 2 then
    vim.notify('Could not parse file path from URL', vim.log.levels.WARN)
    return
  end

  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 or not git_root then
    git_root = nil
  end

  -- Try progressively longer ref prefixes to find the file
  local resolved_path
  for i = 2, #segments do
    local candidate = table.concat(segments, '/', i)

    if vim.fn.filereadable(candidate) == 1 or vim.fn.isdirectory(candidate) == 1 then
      resolved_path = candidate
      break
    end

    if git_root then
      local full = git_root .. '/' .. candidate
      if vim.fn.filereadable(full) == 1 or vim.fn.isdirectory(full) == 1 then
        resolved_path = full
        break
      end
    end
  end

  if not resolved_path then
    local tried_path = table.concat(segments, '/', 2)
    vim.notify('File not found: ' .. tried_path, vim.log.levels.WARN)
    return
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(resolved_path))

  if line_num then
    local line_count = vim.api.nvim_buf_line_count(0)
    if line_num > line_count then
      line_num = line_count
    end
    vim.api.nvim_win_set_cursor(0, { line_num, 0 })
  end

  local display_name = vim.fn.fnamemodify(resolved_path, ':t')
  if line_num then
    vim.notify('Opened ' .. display_name .. ':' .. line_num, vim.log.levels.INFO)
  else
    vim.notify('Opened ' .. display_name, vim.log.levels.INFO)
  end
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

      local ok, pr = pcall(vim.fn.json_decode, result.stdout)
      if not ok or not pr or not pr.number then
        vim.notify('Could not parse PR info', vim.log.levels.ERROR)
        return
      end

      M._open_pr_review(pr.number, pr.title, repo_slug)
    end)
  )
end

return M
