local slack_utils = require('custom.utils.slack')

local M = {}

local GREETINGS = {
  'Good morning!',
  'Mornin\'!',
  'Hey, good morning!',
  'Morning everyone!',
  'Good morning team!',
}

local LOCATIONS = {
  { name = 'WFH', message = 'Working from home today' },
  { name = 'Lysaker', message = 'At Lysaker today' },
}

local function random_greeting()
  return GREETINGS[math.random(#GREETINGS)]
end

function M.post_good_morning()
  local channel = slack_utils.get_default_channel()
  if not channel then
    vim.notify('SLACK_CHANNEL_ID not set', vim.log.levels.WARN)
    return
  end

  vim.ui.select(LOCATIONS, {
    prompt = 'Where are you today?',
    format_item = function(item) return item.name end,
  }, function(selected)
    if not selected then return end

    local message = random_greeting() .. ' ' .. selected.message
    slack_utils.post_message(channel, message, function(success, err)
      vim.schedule(function()
        if success then
          vim.notify('Posted: ' .. message, vim.log.levels.INFO)
        else
          vim.notify('Failed to post: ' .. (err or 'unknown error'), vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

return M
