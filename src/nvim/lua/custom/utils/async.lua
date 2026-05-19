local M = {}

function M.execute(cmd, callback)
  if not cmd or not callback then error('Command and callback are required') end

  local stdout, stderr = {}, {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then table.insert(stdout, line) end
        end
      end
    end,
    on_stderr = function(_, data)
      if data then
        for _, line in ipairs(data) do
          if line ~= '' then table.insert(stderr, line) end
        end
      end
    end,
    on_exit = function(_, code) callback(code == 0, table.concat(stdout, '\n'), table.concat(stderr, '\n'), code) end,
  })
end

function M.run(cmd, on_success, on_error)
  if not cmd then error('Command is required') end

  M.execute(cmd, function(success, stdout, stderr, code)
    if success or code == 1 then
      local out = stdout:gsub('^%s*(.-)%s*$', '%1')
      on_success(out, code)
    else
      local out = stdout:gsub('^%s*(.-)%s*$', '%1')
      local err = stderr:gsub('^%s*(.-)%s*$', '%1')
      on_error(out, err, code)
    end
  end)
end

return M
