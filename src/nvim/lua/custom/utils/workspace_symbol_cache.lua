local M = {}

local CACHE_DIR = vim.fn.stdpath('cache') .. '/workspace_symbols'
local DEFAULT_TTL = 300

local function get_cache_file()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
  local cwd_hash = vim.fn.sha256(cwd):sub(1, 16)
  return CACHE_DIR .. '/symbols_' .. cwd_hash .. '.json'
end

local function ensure_cache_dir()
  if vim.fn.isdirectory(CACHE_DIR) == 0 then
    vim.fn.mkdir(CACHE_DIR, 'p')
  end
end

local function read_cache()
  local cache_file = get_cache_file()
  if vim.fn.filereadable(cache_file) == 0 then
    return nil
  end

  local ok, content = pcall(vim.fn.readfile, cache_file)
  if not ok then
    return nil
  end

  local json_str = table.concat(content, '\n')
  local ok_decode, data = pcall(vim.fn.json_decode, json_str)
  if not ok_decode or not data then
    return nil
  end

  if not data.timestamp or not data.symbols or not data.cwd then
    return nil
  end

  local current_cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
  if data.cwd ~= current_cwd then
    return nil
  end

  return data
end

local function write_cache(symbols)
  ensure_cache_dir()
  local cache_file = get_cache_file()
  local data = {
    timestamp = os.time(),
    cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p'),
    symbols = symbols,
  }

  local json_str = vim.fn.json_encode(data)
  local ok = pcall(vim.fn.writefile, { json_str }, cache_file)
  return ok
end

local function is_cache_valid(cache, ttl)
  ttl = ttl or DEFAULT_TTL
  if not cache or not cache.timestamp then
    return false
  end

  local age = os.time() - cache.timestamp
  return age < ttl
end

function M.get(ttl)
  local cache = read_cache()
  if is_cache_valid(cache, ttl) then
    if type(cache.symbols) == 'table' and #cache.symbols > 0 then
      return cache.symbols
    end
  end
  return nil
end

function M.set(symbols)
  return write_cache(symbols)
end

function M.clear()
  local cache_file = get_cache_file()
  if vim.fn.filereadable(cache_file) == 1 then
    vim.fn.delete(cache_file)
    return true
  end
  return false
end

function M.clear_all()
  if vim.fn.isdirectory(CACHE_DIR) == 1 then
    vim.fn.delete(CACHE_DIR, 'rf')
    return true
  end
  return false
end

return M
