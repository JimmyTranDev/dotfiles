local async = require('custom.utils.async')

local M = {}

local price_text = ''
local timer = nil
local POLL_INTERVAL_MS = 300000

local SYMBOL = 'ASTS'
local QUOTE_URL = 'https://finnhub.io/api/v1/quote?symbol=' .. SYMBOL .. '&token='

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

--- Refresh the cached ASTS quote from Finnhub. No-ops when curl is unavailable
--- or FINNHUB_API_KEY is unset (this runs on a background poll, so it stays
--- silent). A failed request or unparseable body leaves the last-known value
--- untouched.
local function refresh()
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
  end)
end

--- Current formatted quote for the statusline bubble.
---@return string
function M.get_price() return price_text end

--- Start polling for the ASTS quote and register cleanup. Safe to call when curl
--- is missing or FINNHUB_API_KEY is unset (it simply does nothing).
function M.setup()
  if not vim.fn.executable('curl') then return end
  if not vim.env.FINNHUB_API_KEY or vim.env.FINNHUB_API_KEY == '' then return end

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
