local M = {}

local cached_team_members = {}

--- Reset the in-memory team-member cache so the next lookup refetches.
function M.clear_team_cache() cached_team_members = {} end

---@return string[]|nil team_slugs
---@return string|nil org_name
function M.parse_team_config()
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
    if trimmed ~= '' then table.insert(team_slugs, trimmed) end
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

function M.get_team_members_for_slugs(org_name, team_slugs, callback)
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

return M
