local M = {}

function M.escape_pattern(str)
  if type(str) ~= 'string' then return '' end
  return str:gsub('[%^%$%(%)%%%.%[%]%*%+%-%?]', '%%%1')
end

function M.capitalize_first_char(str)
  if not str or str == '' then return str end
  return str:sub(1, 1):upper() .. str:sub(2)
end

return M
