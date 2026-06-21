local M = {}

---@class TerminalOpts
---@field cmd? string Command to run
---@field name? string Display name (auto-generated if nil)
---@field dir? string Working directory
---@field direction? "horizontal"|"vertical"|"float" Direction (default: "horizontal")
---@field close_on_exit? boolean Close terminal when process exits (default: false, keep open)

---@class TerminalInfo
---@field id number Terminal ID
---@field name string Display name
---@field cmd string|nil Command
---@field is_open boolean Whether terminal window is visible
---@field is_alive boolean Whether process is still running

---@type table<string, table>
local _terminals = {}
local _next_id = 1
local _blank_counter = 0

---@param cmd string
---@return string
local function _make_name(cmd)
  local name = cmd:lower()
  name = name:gsub('[^%w%-]', '-')
  name = name:gsub('%-+', '-')
  name = name:gsub('^%-', '')
  name = name:gsub('%-$', '')
  if #name > 40 then
    name = name:sub(1, 40):gsub('%-$', '')
  end
  if name == '' then
    _blank_counter = _blank_counter + 1
    name = 'terminal-' .. _blank_counter
  end
  return name
end

---@param term table
---@return boolean
local function _is_alive(term)
  if not term then return false end
  if not term.bufnr then return true end
  if not vim.api.nvim_buf_is_valid(term.bufnr) then return false end
  if not term.job_id then return false end
  local result = vim.fn.jobwait({ term.job_id }, 0)
  return result[1] == -1
end

---@param base_name string
---@return string
local function _unique_name(base_name)
  local existing = _terminals[base_name]
  if not existing then return base_name end
  if not _is_alive(existing) then
    existing:shutdown()
    _terminals[base_name] = nil
    return base_name
  end
  local i = 2
  while true do
    local candidate = base_name .. '-' .. i
    local candidate_term = _terminals[candidate]
    if not candidate_term then return candidate end
    if not _is_alive(candidate_term) then
      candidate_term:shutdown()
      _terminals[candidate] = nil
      return candidate
    end
    i = i + 1
  end
end

---@param name string
---@param opts TerminalOpts
---@return table
local function _new_term(name, opts)
  local Terminal = require('toggleterm.terminal').Terminal

  local id = _next_id
  _next_id = _next_id + 1

  local term = Terminal:new({
    cmd = opts.cmd,
    count = id,
    direction = opts.direction or 'horizontal',
    display_name = name,
    dir = opts.dir,
    -- Keep terminals open by default; only close when explicitly requested.
    close_on_exit = opts.close_on_exit == true,
  })

  _terminals[name] = term
  return term
end

---@param opts? TerminalOpts
---@return table
function M.create(opts)
  opts = opts or {}

  local name
  if opts.name then
    name = _unique_name(opts.name)
  elseif opts.cmd then
    name = _unique_name(_make_name(opts.cmd))
  else
    _blank_counter = _blank_counter + 1
    name = _unique_name('terminal-' .. _blank_counter)
  end

  return _new_term(name, opts)
end

---@param name string
---@param opts? TerminalOpts
---@return table
function M.get_or_create(name, opts)
  local existing = _terminals[name]
  if existing and _is_alive(existing) then
    existing:toggle()
    return existing
  end

  if existing then
    existing:shutdown()
    _terminals[name] = nil
  end

  local term = _new_term(name, opts or {})
  term:toggle()
  return term
end

--- Kill any existing terminal with this name and start it fresh.
---@param name string
---@param opts? TerminalOpts
---@return table
function M.restart(name, opts)
  local existing = _terminals[name]
  if existing then
    existing:shutdown()
    _terminals[name] = nil
  end

  local term = _new_term(name, opts or {})
  term:toggle()
  return term
end

---@param name string
function M.toggle(name)
  local term = _terminals[name]
  if not term then return end
  term:toggle()
end

---@param name string
function M.kill(name)
  local term = _terminals[name]
  if not term then return end
  term:shutdown()
  _terminals[name] = nil
end

function M.kill_all()
  for _, term in pairs(_terminals) do
    term:shutdown()
  end
  _terminals = {}
end

---@return TerminalInfo[]
function M.list()
  local result = {}
  local dead = {}
  for name, term in pairs(_terminals) do
    if _is_alive(term) then
      table.insert(result, {
        id = term.id,
        name = name,
        cmd = term.cmd,
        is_open = term:is_open(),
        is_alive = true,
      })
    else
      table.insert(dead, name)
    end
  end
  for _, name in ipairs(dead) do
    _terminals[name]:shutdown()
    _terminals[name] = nil
  end
  return result
end

---@param name string
---@return table|nil
function M.get(name)
  return _terminals[name]
end

return M
