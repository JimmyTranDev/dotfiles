local M = {}

--- Normalize a command into argv for vim.system. Strings are run through the
--- shell to preserve the historical string-command behavior; lists run
--- directly without a shell.
---@param cmd string|string[]
---@return string[]
local function to_argv(cmd)
  if type(cmd) == 'string' then return { vim.o.shell, vim.o.shellcmdflag, cmd } end
  return cmd
end

--- Collapse raw output to non-empty lines joined by '\n' (no trailing newline),
--- matching the previous buffered-output contract.
---@param s string|nil
---@return string
local function clean(s)
  local lines = {}
  for line in (s or ''):gmatch('[^\n]+') do
    lines[#lines + 1] = line
  end
  return table.concat(lines, '\n')
end

--- Run a command asynchronously. callback(success, stdout, stderr, code).
--- Accepts a shell string or an argv list.
---@param cmd string|string[]
---@param callback fun(success: boolean, stdout: string, stderr: string, code: integer)
function M.execute(cmd, callback)
  if not cmd or not callback then error('Command and callback are required') end

  vim.system(
    to_argv(cmd),
    { text = true },
    vim.schedule_wrap(function(res)
      local code = res.code or 0
      callback(code == 0, clean(res.stdout), clean(res.stderr), code)
    end)
  )
end

--- Convenience over execute: trims output and treats exit 0 or 1 as success.
---@param cmd string|string[]
---@param on_success fun(stdout: string, code: integer)
---@param on_error fun(stdout: string, stderr: string, code: integer)
function M.run(cmd, on_success, on_error)
  if not cmd then error('Command is required') end

  M.execute(cmd, function(success, stdout, stderr, code)
    local out = stdout:gsub('^%s*(.-)%s*$', '%1')
    if success or code == 1 then
      on_success(out, code)
    else
      on_error(out, stderr:gsub('^%s*(.-)%s*$', '%1'), code)
    end
  end)
end

--- Modern argv-only runner. on_done receives the raw (schedule-wrapped) result.
--- Extra vim.system options (timeout, cwd, env, stdin, ...) merge over { text = true }.
---@param cmd string[]
---@param on_done fun(res: vim.SystemCompleted)
---@param opts? vim.SystemOpts
function M.run_cmd(cmd, on_done, opts)
  if not cmd then error('Command is required') end
  vim.system(cmd, vim.tbl_extend('force', { text = true }, opts or {}), vim.schedule_wrap(on_done))
end

--- Run argv and decode stdout as JSON. On non-zero exit, calls on_err if given,
--- otherwise notifies. On decode failure, notifies.
---@param cmd string[]
---@param on_ok fun(data: any)
---@param on_err? fun(err: string, code: integer)
function M.json(cmd, on_ok, on_err)
  M.run_cmd(cmd, function(res)
    if res.code ~= 0 then
      local err = (res.stderr or ''):gsub('%s+$', '')
      if on_err then return on_err(err, res.code) end
      return vim.notify((cmd[1] or 'command') .. ' error: ' .. err, vim.log.levels.ERROR)
    end
    local ok, data = pcall(vim.json.decode, res.stdout)
    if not ok then return vim.notify('Failed to parse ' .. (cmd[1] or 'command') .. ' output', vim.log.levels.ERROR) end
    on_ok(data)
  end)
end

return M
