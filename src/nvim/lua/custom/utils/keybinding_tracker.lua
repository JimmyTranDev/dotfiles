local json = require('custom.utils.json')

local M = {}

local STATS_FILE = vim.fn.stdpath('data') .. '/keybinding_stats.json'
local stats = {}
local dirty = false
local save_timer = vim.uv.new_timer()
local initialized = false

local function load_stats()
  stats = json.parse_json_from_file(STATS_FILE)
  if type(stats) ~= 'table' then stats = {} end
end

local function save_stats()
  if not dirty then return end
  json.write_json_to_file(STATS_FILE, stats)
  dirty = false
end

local function schedule_save()
  save_timer:stop()
  save_timer:start(5000, 0, vim.schedule_wrap(save_stats))
end

local function record(lhs)
  local current_mode = vim.api.nvim_get_mode().mode:sub(1, 1)
  local key = current_mode .. ':' .. lhs
  if not stats[key] then stats[key] = { count = 0, last_used = 0, mode = current_mode, lhs = lhs } end
  stats[key].count = stats[key].count + 1
  stats[key].last_used = os.time()
  dirty = true
  schedule_save()
end

function M.tracked_set(mode, lhs, rhs, opts)
  opts = vim.tbl_extend('force', { silent = true, noremap = true }, opts or {})
  local use_noremap = opts.noremap ~= false and opts.remap ~= true

  if type(rhs) == 'function' then
    local original_fn = rhs
    local wrapper = function()
      record(lhs)
      return original_fn()
    end
    vim.keymap.set(mode, lhs, wrapper, opts)
  elseif type(rhs) == 'string' then
    local feed_flag = use_noremap and 'n' or 'm'
    local wrapper = function()
      record(lhs)
      local current_mode = vim.fn.mode(true)
      if current_mode:match('[vVsS\22\19]') then vim.api.nvim_feedkeys('gv', 'n', false) end
      local escaped = vim.api.nvim_replace_termcodes(rhs, true, true, true)
      vim.api.nvim_feedkeys(escaped, feed_flag, false)
    end
    opts.noremap = nil
    opts.remap = nil
    vim.keymap.set(mode, lhs, wrapper, opts)
  end
end

function M.get_stats() return stats end

function M.reset_stats()
  stats = {}
  dirty = true
  save_stats()
end

function M.init()
  if initialized then return end
  initialized = true
  load_stats()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      save_timer:stop()
      pcall(save_stats)
    end,
  })
end

return M
