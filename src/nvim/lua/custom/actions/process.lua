local input = require('custom.utils.input')

local M = {}

local function notify(msg, level) vim.notify(msg, level or vim.log.levels.INFO) end

-- Run an argv list (no shell) synchronously. Passing the port/PIDs as discrete
-- argv elements means they are never parsed by a shell, preventing injection.
local function run(args)
  local res = vim.system(args, { text = true }):wait()
  return res.code, res.stdout or '', res.stderr or ''
end

-- Split stdout into trimmed, non-empty lines.
local function lines_of(out)
  local lines = {}
  for line in out:gmatch('[^\r\n]+') do
    local trimmed = line:match('^%s*(.-)%s*$')
    if trimmed ~= '' then table.insert(lines, trimmed) end
  end
  return lines
end

-- Return the TCP listening PIDs bound to `port`, as a list of strings.
local function listening_pids(port)
  local code, out = run({ 'lsof', '-ti', 'tcp:' .. port, '-sTCP:LISTEN' })
  if code ~= 0 then return {} end
  return lines_of(out)
end

-- Prompt for a port, then kill the process(es) listening on it (no confirm).
function M.kill_port()
  if vim.fn.executable('lsof') ~= 1 then
    notify('lsof is not installed', vim.log.levels.ERROR)
    return
  end

  input.get_input('Port to kill: ', function(value)
    if not value then return end

    local port = tonumber(value)
    if not port or port ~= math.floor(port) or port < 1 or port > 65535 then
      notify('Invalid port: ' .. value, vim.log.levels.ERROR)
      return
    end

    local pids = listening_pids(port)
    if #pids == 0 then
      notify('No process listening on port ' .. port, vim.log.levels.WARN)
      return
    end

    local args = { 'kill', '-9' }
    for _, pid in ipairs(pids) do
      table.insert(args, pid)
    end

    local code, _, stderr = run(args)
    if code == 0 then
      notify('Killed ' .. #pids .. ' process(es) on port ' .. port)
    else
      notify('Failed to kill process on port ' .. port .. (stderr ~= '' and (': ' .. stderr) or ''), vim.log.levels.ERROR)
    end
  end)
end

return M
