local M = {}

local STOCKS_FILE = vim.fn.expand('~/.config/nvim/stocks.txt')
local GEMINI_URL = 'https://gemini.google.com/app'

local function read_tickers()
  if vim.fn.filereadable(STOCKS_FILE) == 0 then return nil end

  local lines = vim.fn.readfile(STOCKS_FILE)
  local tickers = {}
  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)
    if trimmed ~= '' then table.insert(tickers, trimmed) end
  end

  if #tickers == 0 then return nil end

  return tickers
end

local function build_prompt(tickers)
  local ticker_list = table.concat(tickers, ', ')
  return string.format("Summarize today's market performance for these stocks: %s. Include price changes, percentage moves, and any notable news.", ticker_list)
end

function M.copy_and_open()
  local tickers = read_tickers()
  if not tickers then
    vim.notify('Create ' .. STOCKS_FILE .. ' with one ticker per line', vim.log.levels.ERROR)
    return
  end

  local prompt = build_prompt(tickers)
  vim.fn.setreg('+', prompt)

  local ok = pcall(vim.ui.open, GEMINI_URL)
  if not ok then vim.system({ 'open', GEMINI_URL }, { detach = true }) end

  vim.notify('Prompt copied! Paste in Gemini.', vim.log.levels.INFO)
end

function M.setup() vim.keymap.set('n', '<Leader>ss', M.copy_and_open, { desc = 'Stock summary via Gemini' }) end

return M
