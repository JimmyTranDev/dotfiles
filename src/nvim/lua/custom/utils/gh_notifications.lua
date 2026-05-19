local async = require('custom.utils.async')

local M = {}

local notification_count = 0
local timer = nil
local POLL_INTERVAL_MS = 300000

local function refresh()
  if not vim.fn.executable('gh') then
    return
  end

  async.run(
    'gh api notifications --jq \'[.[] | select(.subject.type == "PullRequest")] | length\'',
    function(output)
      local count = tonumber(output) or 0
      notification_count = count
      vim.g.gh_pr_comment_count = count
    end,
    function() end
  )
end

function M.get_count()
  if notification_count == 0 then
    return ''
  end
  return ' ' .. notification_count
end

function M.setup()
  if not vim.fn.executable('gh') then
    return
  end

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
