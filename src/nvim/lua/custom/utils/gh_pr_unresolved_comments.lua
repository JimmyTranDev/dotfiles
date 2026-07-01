local async = require('custom.utils.async')

local M = {}

local comment_count = 0
local timer = nil
local POLL_INTERVAL_MS = 300000

-- Count unresolved review threads across the viewer's own open PRs. Using
-- `viewer` avoids needing a username; first: 100 comfortably covers a person's
-- open PRs and the threads on each without pagination.
local QUERY = [[
query {
  viewer {
    pullRequests(states: OPEN, first: 100) {
      nodes {
        reviewThreads(first: 100) {
          nodes { isResolved }
        }
      }
    }
  }
}
]]

local JQ = '[.data.viewer.pullRequests.nodes[]? | .reviewThreads.nodes[]? | select(.isResolved == false)] | length'

--- Format the unresolved-comment count for the statusline. Returns '' when there
--- is nothing to show (which hides the bubble via its `cond`); otherwise a
--- leading-space-padded count, e.g. ' 3'. The bubble's leading icon is supplied
--- by the statusline, so this is the bare number.
---@param count integer|nil
---@return string
function M.format_count(count)
  if type(count) ~= 'number' or count <= 0 then return '' end
  return ' ' .. count
end

--- Refresh the cached count of unresolved review threads on the user's own open
--- PRs. No-ops when gh is unavailable; a failed query leaves the last-known
--- count untouched.
local function refresh()
  if not vim.fn.executable('gh') then return end

  async.run_cmd({ 'gh', 'api', 'graphql', '-f', 'query=' .. QUERY, '--jq', JQ }, function(res)
    if res.code ~= 0 then return end
    comment_count = tonumber(res.stdout) or 0
    vim.g.gh_pr_unresolved_comment_count = comment_count
  end)
end

--- Current formatted count for the statusline bubble.
---@return string
function M.get_count() return M.format_count(comment_count) end

--- Start polling for the unresolved-comment count and register cleanup. Safe to
--- call when gh is missing (it simply does nothing).
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
