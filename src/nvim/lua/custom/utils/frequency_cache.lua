local json = require('custom.utils.json')

local M = {}

local CACHE_FILE = vim.fn.stdpath('data') .. '/frequency_cache.json'
local data = nil

local function load()
  if data then return end
  data = json.parse_json_from_file(CACHE_FILE)
  if type(data) ~= 'table' then data = {} end
end

local function save()
  json.write_json_to_file(CACHE_FILE, data)
end

function M.record(namespace, key)
  load()
  if not data[namespace] then data[namespace] = {} end
  if not data[namespace][key] then data[namespace][key] = 0 end
  data[namespace][key] = data[namespace][key] + 1
  save()
end

function M.get_count(namespace, key)
  load()
  if not data[namespace] then return 0 end
  return data[namespace][key] or 0
end

function M.sort_by_frequency(namespace, items, key_fn)
  load()
  local counts = data[namespace] or {}
  table.sort(items, function(a, b)
    local count_a = counts[key_fn(a)] or 0
    local count_b = counts[key_fn(b)] or 0
    if count_a ~= count_b then return count_a > count_b end
    return (a.text or '') < (b.text or '')
  end)
  return items
end

function M.clear(namespace)
  load()
  data[namespace] = nil
  save()
end

return M
