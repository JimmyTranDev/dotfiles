local M = {}

function M.string(value, min_length, max_length)
  if type(value) ~= 'string' then return false, 'Expected string, got ' .. type(value) end

  local min_len = min_length or 1
  if #value < min_len then return false, string.format('String must be at least %d characters', min_len) end

  if max_length and #value > max_length then return false, string.format('String must be no more than %d characters', max_length) end

  return true
end

return M
