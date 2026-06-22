local github_utils = require('custom.utils.github')
local file_utils = require('custom.utils.files')
local usage_cache = require('custom.utils.usage_cache')
local util = require('custom.actions.github.util')

local parse_team_config = util.parse_team_config
local get_team_members_for_slugs = util.get_team_members_for_slugs

local M = {}

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

  util.clear_team_cache()
  vim.notify('Refreshing team members cache...', vim.log.levels.INFO)
  get_team_members_for_slugs(org_name, team_slugs, function(members) vim.notify('Cached ' .. #members .. ' team members', vim.log.levels.INFO) end)
end

local function fetch_and_show_prs(org_name, usernames)
  if #usernames == 0 then
    vim.notify('No members found', vim.log.levels.ERROR)
    return
  end

  vim.notify('Fetching open PRs for ' .. #usernames .. ' team members...', vim.log.levels.INFO)

  local all_prs = {}
  local seen_urls = {}
  local pending = #usernames

  local function add_pr(pr)
    if pr.url and seen_urls[pr.url] then return end
    if pr.url then seen_urls[pr.url] = true end
    table.insert(all_prs, pr)
  end

  local function show_picker()
    if #all_prs == 0 then
      vim.notify('No open PRs found for team members', vim.log.levels.INFO)
      return
    end

    table.sort(all_prs, function(a, b)
      local a_created = a.created_at or ''
      local b_created = b.created_at or ''
      if a_created ~= b_created then return a_created > b_created end
      if a.author ~= b.author then return a.author < b.author end
      return a.repo < b.repo
    end)

    github_utils.append_review_decisions(all_prs, function(enriched_prs)
      local snacks_ok, snacks = pcall(require, 'snacks')
      if not snacks_ok then return end

      snacks.picker({
        title = 'Open PRs by People',
        items = enriched_prs,
        format = function(item) return { { item.text, 'Normal' } } end,
        confirm = function(picker, item)
          picker:close()
          file_utils.open(item.url)
          vim.notify('Opened PR #' .. item.number .. ' in browser', vim.log.levels.INFO)
        end,
      })
    end)
  end

  -- After team PRs are collected, merge in the current user's own open PRs
  -- across all configured owners (previously the standalone `ugm` picker).
  local function merge_my_prs_and_show()
    github_utils.get_current_login(function(my_login)
      github_utils.fetch_my_prs_across_owners(github_utils.get_github_owners(), {}, function(my_prs)
        for _, pr in ipairs(my_prs) do
          local author = my_login or 'me'
          add_pr({
            text = string.format('[%s] #%d %s [%s]', author, pr.number, pr.title, pr.repo),
            number = pr.number,
            title = pr.title,
            url = pr.url,
            repo = pr.repo,
            author = author,
            draft = pr.draft,
            created_at = pr.created_at,
          })
        end
        show_picker()
      end)
    end)
  end

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
        'number,title,repository,url,isDraft,createdAt',
        '--limit',
        '100',
      },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 and result.stdout and result.stdout ~= '' then
          local ok, prs = pcall(vim.json.decode, result.stdout)
          if ok and type(prs) == 'table' then
            for _, pr in ipairs(prs) do
              local repo_name = pr.repository and pr.repository.nameWithOwner or ''
              add_pr({
                text = string.format('[%s] #%d %s [%s]', username, pr.number, pr.title, repo_name),
                number = pr.number,
                title = pr.title,
                url = pr.url,
                repo = repo_name,
                author = username,
                draft = pr.isDraft,
                created_at = pr.createdAt,
              })
            end
          end
        end

        pending = pending - 1
        if pending > 0 then return end

        merge_my_prs_and_show()
      end)
    )
  end
end

function M.select_open_prs_by_people()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then return end

  local choices = {}
  for _, slug in ipairs(team_slugs) do
    table.insert(choices, { text = slug, slugs = { slug } })
  end
  table.insert(choices, { text = 'All teams', slugs = team_slugs })

  vim.ui.select(choices, {
    prompt = 'Select team:',
    format_item = function(item) return item.text end,
  }, function(choice)
    if not choice then return end
    get_team_members_for_slugs(org_name, choice.slugs, function(usernames) fetch_and_show_prs(org_name, usernames) end)
  end)
end

function M.select_open_prs_by_default_team()
  local team_slugs, org_name = parse_team_config()
  if not team_slugs or not org_name then return end

  get_team_members_for_slugs(org_name, { team_slugs[1] }, function(usernames) fetch_and_show_prs(org_name, usernames) end)
end

function M.list_org_repos_and_open()
  local programming_dir = vim.fn.expand('~/Programming')
  local org_exclude = { Worktrees = true, wcreated = true, wcheckout = true }

  local items = {}

  for _, org in ipairs(file_utils.scan(programming_dir, { type = 'directory', exclude = org_exclude, hidden = true })) do
    for _, repo in ipairs(file_utils.scan(org.path, { type = 'directory', hidden = true })) do
      table.insert(items, {
        text = '[' .. org.name .. '] ' .. repo.name,
        name = repo.name,
        url = 'https://github.com/' .. org.name .. '/' .. repo.name,
        org = org.name,
      })
    end
  end

  table.sort(items, function(a, b) return a.text < b.text end)

  usage_cache.sort_by_frequency('org_repos', items, function(item) return item.org .. '/' .. item.name end)

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
      usage_cache.record('org_repos', item.org .. '/' .. item.name)
      file_utils.open(item.url)
      vim.notify('Opened ' .. item.name .. ' in browser', vim.log.levels.INFO)
    end,
  })
end

return M
