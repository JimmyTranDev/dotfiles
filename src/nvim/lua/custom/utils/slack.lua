local M = {}

function M.get_token()
  local token = os.getenv('SLACK_BOT_TOKEN')
  if not token or token == '' then
    return nil
  end
  return token
end

function M.get_default_channel()
  local channel = os.getenv('SLACK_CHANNEL_ID')
  if not channel or channel == '' then
    return nil
  end
  return channel
end

function M.post_message(channel_id, text, callback)
  local token = M.get_token()
  if not token then
    callback(false, 'SLACK_BOT_TOKEN not set. Set it in your environment.')
    return
  end

  vim.system(
    {
      'curl', '-s', '-X', 'POST',
      'https://slack.com/api/chat.postMessage',
      '-H', 'Authorization: Bearer ' .. token,
      '-H', 'Content-type: application/json; charset=utf-8',
      '-d', vim.fn.json_encode({ channel = channel_id, text = text }),
    },
    {},
    function(result)
      if result.code ~= 0 then
        callback(false, 'curl failed: ' .. (result.stderr or ''))
        return
      end

      local ok, data = pcall(vim.fn.json_decode, result.stdout)
      if not ok or not data then
        callback(false, 'Failed to parse Slack response')
        return
      end

      if data.ok then
        callback(true, nil)
      else
        callback(false, 'Slack API error: ' .. (data.error or 'unknown'))
      end
    end
  )
end

return M
