local json = require('custom.utils.json')

local M = {}

local CACHE_FILE = vim.fn.stdpath('data') .. '/usage_cache.json'
local data = nil

local function load()
  if data then return end
  data = json.parse_json_from_file(CACHE_FILE)
  if type(data) ~= 'table' then data = {} end
  -- Normalize legacy number entries ({ key = count }) to { count, last_used }.
  for _, entries in pairs(data) do
    if type(entries) == 'table' then
      for key, value in pairs(entries) do
        if type(value) == 'number' then entries[key] = { count = value, last_used = 0 } end
      end
    end
  end
end

local function save() json.write_json_to_file(CACHE_FILE, data) end

local function entry(namespace, key)
  if not data[namespace] then data[namespace] = {} end
  if not data[namespace][key] then data[namespace][key] = { count = 0, last_used = 0 } end
  return data[namespace][key]
end

function M.record(namespace, key)
  load()
  local e = entry(namespace, key)
  e.count = e.count + 1
  e.last_used = os.time()
  save()
end

function M.get_count(namespace, key)
  load()
  local ns = data[namespace]
  if not ns or not ns[key] then return 0 end
  return ns[key].count or 0
end

function M.get_last_used(namespace, key)
  load()
  local ns = data[namespace]
  if not ns or not ns[key] then return 0 end
  return ns[key].last_used or 0
end

function M.sort_by_frequency(namespace, items, key_fn)
  load()
  local entries = data[namespace] or {}
  table.sort(items, function(a, b)
    local count_a = (entries[key_fn(a)] or {}).count or 0
    local count_b = (entries[key_fn(b)] or {}).count or 0
    if count_a ~= count_b then return count_a > count_b end
    return (a.text or '') < (b.text or '')
  end)
  return items
end

function M.sort_by_recency(namespace, items, key_fn)
  load()
  local entries = data[namespace] or {}
  table.sort(items, function(a, b)
    local recency_a = (entries[key_fn(a)] or {}).last_used or 0
    local recency_b = (entries[key_fn(b)] or {}).last_used or 0
    if recency_a ~= recency_b then return recency_a > recency_b end
    return (a.text or '') < (b.text or '')
  end)
  return items
end

--- Return up to `n` keys in the namespace, most-recently-used first.
---@param namespace string
---@param n? integer max keys to return (default: all)
---@return string[]
function M.recent(namespace, n)
  load()
  local entries = data[namespace] or {}
  local keys = {}
  for key, e in pairs(entries) do
    keys[#keys + 1] = { key = key, last_used = e.last_used or 0 }
  end
  table.sort(keys, function(a, b) return a.last_used > b.last_used end)
  local out = {}
  for i = 1, math.min(n or #keys, #keys) do
    out[#out + 1] = keys[i].key
  end
  return out
end

function M.clear(namespace)
  load()
  data[namespace] = nil
  save()
end

return M
