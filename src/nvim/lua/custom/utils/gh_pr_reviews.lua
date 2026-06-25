local async = require('custom.utils.async')

local M = {}

local review_count = 0
local timer = nil
local POLL_INTERVAL_MS = 300000

--- Format the open-review count for the statusline. Returns '' when there is
--- nothing awaiting review (which hides the bubble via its `cond`); otherwise a
--- leading-space-padded count, e.g. ' 3'.
---@param count integer|nil
---@return string
function M.format_count(count)
  if type(count) ~= 'number' or count <= 0 then return '' end
  return ' ' .. count
end

--- Refresh the cached count of open PRs awaiting the user's review. Uses the
--- GitHub search API's total_count so the value is exact regardless of result
--- pagination. No-ops when gh is unavailable; a failed query leaves the last
--- known count untouched.
local function refresh()
  if not vim.fn.executable('gh') then return end

  async.run("gh api -X GET search/issues -f q='is:open is:pr review-requested:@me' --jq '.total_count'", function(output)
    review_count = tonumber(output) or 0
    vim.g.gh_review_requested_count = review_count
  end, function() end)
end

--- Current formatted count of open PRs awaiting the user's review.
---@return string
function M.get_count() return M.format_count(review_count) end

--- Start polling for the review count and register cleanup. Safe to call when
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
