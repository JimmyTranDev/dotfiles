local async = require('custom.utils.async')

local M = {}

local price_text = ''
local timer = nil
local POLL_INTERVAL_MS = 300000
local CACHE_TTL_SECONDS = 300

local SYMBOL = 'ASTS'
local QUOTE_URL = 'https://finnhub.io/api/v1/quote?symbol=' .. SYMBOL .. '&token='

-- Shared cache file so every nvim instance reads one quote instead of each
-- polling Finnhub. Resolved lazily (stdpath is unavailable at require time in
-- some headless contexts) and overridable for tests via _set_cache_file.
local cache_file_override = nil
local function cache_file()
  return cache_file_override or (vim.fn.stdpath('cache') .. '/asts_price.json')
end

--- Format an ASTS quote for the statusline. Returns '' when there is nothing to
--- show (which hides the bubble via its `cond`) — a nil, non-number, or
--- non-positive price means no valid quote yet. Otherwise renders
--- 'ASTS <price> <±change%>' with the price to 2dp and the percent change
--- signed to 2dp, e.g. 'ASTS 42.15 +1.80%'. A missing change is treated as 0.
--- The bubble's leading icon is supplied by the statusline, so this is the bare
--- text.
---@param price number|nil
---@param change number|nil
---@return string
function M.format_price(price, change)
  if type(price) ~= 'number' or price <= 0 then return '' end
  local pct = type(change) == 'number' and change or 0
  return string.format('%s %.2f %+.2f%%', SYMBOL, price, pct)
end

--- Whether a cache entry is still within the TTL relative to `now` (defaults to
--- the current time). A nil entry or one missing a timestamp is never fresh.
---@param entry table|nil
---@param now integer|nil
---@return boolean
function M.is_fresh(entry, now)
  if type(entry) ~= 'table' or type(entry.timestamp) ~= 'number' then return false end
  return (now or os.time()) - entry.timestamp < CACHE_TTL_SECONDS
end

--- Read the shared cache entry ({ timestamp, text }). Returns nil when the file
--- is absent, unreadable, or malformed.
---@return table|nil
function M.read_cache()
  local file = cache_file()
  if vim.fn.filereadable(file) == 0 then return nil end

  local ok, content = pcall(vim.fn.readfile, file)
  if not ok then return nil end

  local decoded_ok, data = pcall(vim.json.decode, table.concat(content, '\n'))
  if not decoded_ok or type(data) ~= 'table' then return nil end
  if type(data.timestamp) ~= 'number' or type(data.text) ~= 'string' then return nil end

  return data
end

--- Write the formatted quote to the shared cache for other instances to reuse.
--- Best-effort: silently no-ops on any filesystem error.
---@param text string
function M.write_cache(text)
  local file = cache_file()
  local dir = vim.fn.fnamemodify(file, ':h')
  if vim.fn.isdirectory(dir) == 0 then pcall(vim.fn.mkdir, dir, 'p') end

  local encoded_ok, json = pcall(vim.json.encode, { timestamp = os.time(), text = text })
  if not encoded_ok then return end
  pcall(vim.fn.writefile, { json }, file)
end

--- Override the cache file path (tests only).
---@param path string|nil
function M._set_cache_file(path) cache_file_override = path end

--- Refresh the cached ASTS quote. First adopts a fresh shared-cache entry (so
--- only one nvim instance per TTL actually hits Finnhub); otherwise fetches from
--- Finnhub over curl and writes the result to the shared cache. No-ops when curl
--- is unavailable or FINNHUB_API_KEY is unset (this runs on a background poll, so
--- it stays silent). A failed request or unparseable body leaves the last-known
--- value untouched.
local function refresh()
  local cached = M.read_cache()
  if M.is_fresh(cached) then
    price_text = cached.text
    vim.g.asts_price = cached.text
    return
  end

  if not vim.fn.executable('curl') then return end

  local token = vim.env.FINNHUB_API_KEY
  if not token or token == '' then return end

  async.run_cmd({ 'curl', '-fsS', QUOTE_URL .. token }, function(res)
    if res.code ~= 0 then return end

    local ok, quote = pcall(vim.json.decode, res.stdout)
    if not ok or type(quote) ~= 'table' then return end

    local text = M.format_price(quote.c, quote.dp)
    if text == '' then return end

    price_text = text
    vim.g.asts_price = text
    M.write_cache(text)
  end)
end

--- Current formatted quote for the statusline bubble.
---@return string
function M.get_price() return price_text end

--- Start polling for the ASTS quote and register cleanup. Safe to call when curl
--- is missing or FINNHUB_API_KEY is unset (it still seeds from a fresh shared
--- cache, so a new window shows the last-known price even without a key).
function M.setup()
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
