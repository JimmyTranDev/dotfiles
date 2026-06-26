local async = require('custom.utils.async')
local gh_team = require('custom.actions.github.util')

local M = {}

-- Nerd Font (Material Design) glyphs, the same family as the statusline's other
-- GitHub icons. Swap these constants to restyle the bubble.
M.READY_ICON = '󰓂' -- source-pull: ready (non-draft) team PRs; the bubble's leading icon
M.DRAFT_ICON = '󰏫' -- pencil: draft team PRs; rendered inline in the value

local ready_count = 0
local draft_count = 0
local timer = nil
local POLL_INTERVAL_MS = 300000

--- Format the main team's open-PR counts for the statusline. Returns '' when
--- there is nothing to show (which hides the bubble via its `cond`). Otherwise a
--- leading-space-padded string: the ready count, then the draft icon + draft
--- count, each segment omitted when its count is <= 0. The bubble's leading icon
--- (READY_ICON) is supplied by the statusline, so the ready segment is the bare
--- number, e.g. ' 3', ' 3 󰏫 2', or ' 󰏫 2'.
---@param ready integer|nil
---@param draft integer|nil
---@return string
function M.format_counts(ready, draft)
  local r = (type(ready) == 'number' and ready > 0) and ready or 0
  local d = (type(draft) == 'number' and draft > 0) and draft or 0
  if r == 0 and d == 0 then return '' end

  local segments = {}
  if r > 0 then table.insert(segments, tostring(r)) end
  if d > 0 then table.insert(segments, M.DRAFT_ICON .. ' ' .. d) end
  return ' ' .. table.concat(segments, ' ')
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

--- Tally a single member's open PRs into ready/draft buckets, deduping by URL
--- against the shared `seen` set. Reports ok=false when the gh query fails so
--- the caller can leave the last-known counts untouched. Callbacks are
--- serialized on the main loop, so the shared set is safe to mutate here.
---@param on_done fun(ok: boolean, ready: integer, draft: integer)
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
    'isDraft,url',
    '--limit',
    '100',
  }, function(res)
    if res.code ~= 0 then return on_done(false, 0, 0) end

    local ready, draft = 0, 0
    if res.stdout and res.stdout ~= '' then
      local ok, prs = pcall(vim.json.decode, res.stdout)
      if ok and type(prs) == 'table' then
        for _, pr in ipairs(prs) do
          local url = pr.url
          if not url or not seen[url] then
            if url then seen[url] = true end
            if pr.isDraft then
              draft = draft + 1
            else
              ready = ready + 1
            end
          end
        end
      end
    end
    on_done(true, ready, draft)
  end)
end

--- Commit freshly tallied counts to the cache and mirror them onto vim.g.
local function commit_counts(ready, draft)
  ready_count = ready
  draft_count = draft
  vim.g.gh_team_open_pr_count = ready
  vim.g.gh_team_draft_pr_count = draft
end

--- Refresh the cached counts of the main team's open PRs (those authored by
--- team members), split into ready (non-draft) and draft. No-ops when gh is
--- missing or the env vars are unset. Counts are only updated when the whole
--- refresh succeeds (members resolved and every query returned), so a transient
--- failure leaves the last-known counts untouched.
local function refresh()
  if not vim.fn.executable('gh') then return end

  local team_slug, org_name = main_team_config()
  if not team_slug or not org_name then return end

  gh_team.get_team_members_for_slugs(org_name, { team_slug }, function(usernames)
    -- An empty list means the team membership could not be resolved (the helper
    -- also returns empty on API failure); keep the last-known counts.
    if #usernames == 0 then return end

    local seen = {}
    local r_total, d_total = 0, 0
    local pending = #usernames
    local had_error = false

    for _, username in ipairs(usernames) do
      tally_member_prs(org_name, username, seen, function(ok, ready, draft)
        if not ok then had_error = true end
        r_total = r_total + ready
        d_total = d_total + draft
        pending = pending - 1
        if pending > 0 then return end
        if had_error then return end -- leave last-known counts untouched

        commit_counts(r_total, d_total)
      end)
    end
  end)
end

--- Current formatted counts for the statusline bubble.
---@return string
function M.get_counts() return M.format_counts(ready_count, draft_count) end

--- Start polling for the team PR counts and register cleanup. Safe to call when
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
