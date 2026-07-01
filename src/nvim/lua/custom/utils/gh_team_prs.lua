local async = require('custom.utils.async')
local gh_team = require('custom.actions.github.util')

local M = {}

local pr_count = 0
local timer = nil
local POLL_INTERVAL_MS = 300000

--- Format the main team's open-PR count for the statusline. Returns '' when
--- there is nothing to show (which hides the bubble via its `cond`); otherwise a
--- leading-space-padded count, e.g. ' 3'. The bubble's leading icon is supplied
--- by the statusline, so this is the bare number.
---@param count integer|nil
---@return string
function M.format_count(count)
  if type(count) ~= 'number' or count <= 0 then return '' end
  return ' ' .. count
end

--- Read the main GitHub team slug (the first entry of GITHUB_PR_FILTER_TEAMS)
--- and the org from the environment. Returns nil silently (no notification)
--- when unset, since this runs on a background poll.
---@return string|nil team_slug
---@return string|nil org_name
local function main_team_config()
  local teams_str = vim.env.GITHUB_PR_FILTER_TEAMS
  local org_name = vim.env.ORG_GITHUB_NAME
  if not teams_str or teams_str == '' or not org_name or org_name == '' then return nil, nil end

  for slug in teams_str:gmatch('[^,]+') do
    local trimmed = slug:match('^%s*(.-)%s*$')
    if trimmed ~= '' then return trimmed, org_name end
  end
  return nil, nil
end

--- Tally a single member's open PRs (draft or not) into a count, deduping by URL
--- against the shared `seen` set. Reports ok=false when the gh query fails so the
--- caller can leave the last-known count untouched. Callbacks are serialized on
--- the main loop, so the shared set is safe to mutate here.
---@param on_done fun(ok: boolean, count: integer)
local function tally_member_prs(org_name, username, seen, on_done)
  async.run_cmd({
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
    'url',
    '--limit',
    '100',
  }, function(res)
    if res.code ~= 0 then return on_done(false, 0) end

    local count = 0
    if res.stdout and res.stdout ~= '' then
      local ok, prs = pcall(vim.json.decode, res.stdout)
      if ok and type(prs) == 'table' then
        for _, pr in ipairs(prs) do
          local url = pr.url
          if not url or not seen[url] then
            if url then seen[url] = true end
            count = count + 1
          end
        end
      end
    end
    on_done(true, count)
  end)
end

--- Refresh the cached count of the main team's open PRs (those authored by team
--- members), draft or not. No-ops when gh is missing or the env vars are unset.
--- The count is only updated when the whole refresh succeeds (members resolved
--- and every query returned), so a transient failure leaves the last-known count
--- untouched.
local function refresh()
  if not vim.fn.executable('gh') then return end

  local team_slug, org_name = main_team_config()
  if not team_slug or not org_name then return end

  gh_team.get_team_members_for_slugs(org_name, { team_slug }, function(usernames)
    -- An empty list means the team membership could not be resolved (the helper
    -- also returns empty on API failure); keep the last-known count.
    if #usernames == 0 then return end

    local seen = {}
    local total = 0
    local pending = #usernames
    local had_error = false

    for _, username in ipairs(usernames) do
      tally_member_prs(org_name, username, seen, function(ok, count)
        if not ok then had_error = true end
        total = total + count
        pending = pending - 1
        if pending > 0 then return end
        if had_error then return end -- leave last-known count untouched

        pr_count = total
        vim.g.gh_team_open_pr_count = total
      end)
    end
  end)
end

--- Current formatted count for the statusline bubble.
---@return string
function M.get_count() return M.format_count(pr_count) end

--- Start polling for the team PR count and register cleanup. Safe to call when
--- gh is missing (it simply does nothing).
function M.setup()
  if not vim.fn.executable('gh') then return end

  vim.schedule(refresh)

  timer = vim.uv.new_timer()
  timer:start(POLL_INTERVAL_MS, POLL_INTERVAL_MS, vim.schedule_wrap(refresh))

  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if timer then
        timer:stop()
        timer:close()
        timer = nil
      end
    end,
  })
end

return M
