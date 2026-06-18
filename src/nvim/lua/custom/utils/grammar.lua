local M = {}

-- harper-cli wraps its replacement text in typographic quotes: Replace with: “X”
local REPLACE_PATTERN = 'Replace with: \226\128\156(.*)\226\128\157'

local function extract_replacement(suggestion)
  if type(suggestion) ~= 'string' then return nil end
  return suggestion:match(REPLACE_PATTERN)
end

-- Apply harper's lints to `text`. Each lint carries a character span and a list
-- of suggestions; we take the first "Replace with" suggestion per lint. Lints
-- are applied left-to-right with a cursor so overlapping spans are skipped and
-- char offsets stay valid (we rebuild the string from multibyte-safe segments).
local function apply_lints(text, lints)
  local fixes = {}
  for _, lint in ipairs(lints) do
    local span = lint.span
    local replacement = extract_replacement(lint.suggestions and lint.suggestions[1])
    if span and replacement then
      table.insert(fixes, { start = span.char_start, finish = span.char_end, replacement = replacement })
    end
  end

  if #fixes == 0 then return text end

  table.sort(fixes, function(a, b) return a.start < b.start end)

  local chars = vim.fn.split(text, '\\zs')
  local result = {}
  local cursor = 0
  for _, fix in ipairs(fixes) do
    if fix.start >= cursor then
      table.insert(result, table.concat(chars, '', cursor + 1, fix.start))
      table.insert(result, fix.replacement)
      cursor = fix.finish
    end
  end
  table.insert(result, table.concat(chars, '', cursor + 1, #chars))
  return table.concat(result)
end

-- Run harper-cli over `text` and return a grammar-corrected copy. Returns the
-- original text untouched if harper-cli is missing, fails, or finds nothing.
function M.fix(text)
  if not text or text == '' then return text end
  if vim.fn.executable('harper-cli') == 0 then return text end

  local ok, result = pcall(function()
    return vim.system({ 'harper-cli', 'lint', '--format', 'json', '-d', 'us' }, { stdin = text }):wait()
  end)
  if not ok or not result or not result.stdout or result.stdout == '' then return text end

  local decoded_ok, decoded = pcall(vim.json.decode, result.stdout)
  if not decoded_ok or type(decoded) ~= 'table' or not decoded[1] then return text end

  local lints = decoded[1].lints
  if type(lints) ~= 'table' or #lints == 0 then return text end

  local fixed_ok, fixed = pcall(apply_lints, text, lints)
  if not fixed_ok or type(fixed) ~= 'string' then return text end
  return fixed
end

return M
