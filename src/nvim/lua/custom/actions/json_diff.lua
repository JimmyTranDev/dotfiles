-- JSON diff scratchpad: prompt for two JSON blobs one at a time via floating
-- text-area inputs, format both (jq if available, else Neovim's vim.json) with
-- sorted keys, then open them side-by-side in a new tab and run a native vim
-- diff so the two documents line up with real diff highlighting (key order
-- differences are normalised away).
--
-- Flow (M.diff_from_input, bound to `<leader>;d`):
--   1. Floating input for JSON A.
--   2. Floating input for JSON B.
--   3. Format both and open a new tab with two vsplit `json` scratch buffers
--      (left = A, right = B) in diff mode.
-- Cancelling or leaving either input empty aborts the whole flow with a notify.
local M = {}

local ui_utils = require('custom.utils.ui')

local SCRATCH_NAME = 'json-diff://%s'

local INDENT = '  '

-- Recursively pretty-print a Lua value decoded from JSON into indented lines with
-- 2-space indentation and stable (sorted) object key order, so two structurally
-- equal documents format identically and diff cleanly. Used only on the jq-less
-- fallback path. `vim.NIL` (JSON null) is emitted as `null`; empty tables decode
-- ambiguously so `vim.empty_dict()`-tagged tables render as `{}` and everything
-- else empty renders as `[]`.
local function encode_pretty(value, indent, out)
  local t = type(value)
  if t == 'table' then
    local is_array = vim.islist(value)
    if next(value) == nil then
      out[#out + 1] = getmetatable(value) == getmetatable(vim.empty_dict()) and '{}' or '[]'
      return
    end
    local open, close = is_array and '[' or '{', is_array and ']' or '}'
    local child = indent .. INDENT
    out[#out + 1] = open .. '\n'
    if is_array then
      for i, item in ipairs(value) do
        out[#out + 1] = child
        encode_pretty(item, child, out)
        out[#out + 1] = (i < #value and ',' or '') .. '\n'
      end
    else
      local keys = vim.tbl_keys(value)
      table.sort(keys)
      for i, key in ipairs(keys) do
        out[#out + 1] = child .. vim.json.encode(tostring(key)) .. ': '
        encode_pretty(value[key], child, out)
        out[#out + 1] = (i < #keys and ',' or '') .. '\n'
      end
    end
    out[#out + 1] = indent .. close
  elseif t == 'boolean' or t == 'number' then
    out[#out + 1] = tostring(value)
  elseif t == 'string' then
    out[#out + 1] = vim.json.encode(value)
  else
    -- JSON null (vim.NIL) and any unexpected non-JSON type.
    out[#out + 1] = 'null'
  end
end

-- Pretty-print `text` as JSON with sorted object keys so two documents that
-- differ only in key order compare equal. Prefer `jq -S .` for canonical
-- output; fall back to decode via Neovim's built-in vim.json plus a local
-- recursive (key-sorting) pretty-printer when jq is not installed. Returns
-- `formatted, err` — on failure `formatted` is nil and `err` says why.
local function format_json(text)
  if vim.trim(text) == '' then return nil, 'buffer is empty' end

  if vim.fn.executable('jq') == 1 then
    local out = vim.fn.systemlist({ 'jq', '-S', '.' }, text)
    if vim.v.shell_error == 0 then return out end
    -- jq failed: surface its stderr-ish message (systemlist merges it into out).
    return nil, 'invalid JSON (' .. (out[1] or 'jq error') .. ')'
  end

  local ok, decoded = pcall(vim.json.decode, text)
  if not ok then return nil, 'invalid JSON (' .. tostring(decoded) .. ')' end
  local parts = {}
  encode_pretty(decoded, '', parts)
  return vim.split(table.concat(parts), '\n', { plain = true })
end

-- Create a listed=false, wiped-on-hide scratch buffer tagged as JSON with a
-- recognisable name, seeded with the given formatted lines, returning its bufnr.
local function make_scratch(side, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'json'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  pcall(vim.api.nvim_buf_set_name, buf, string.format(SCRATCH_NAME, side))
  return buf
end

-- Open a new tab with two side-by-side scratch buffers (left = A, right = B)
-- seeded with the pre-formatted lines, then enable native diff mode on both.
local function open_diff(left_lines, right_lines)
  vim.cmd('tabnew')
  local left = make_scratch('a', left_lines)
  vim.api.nvim_win_set_buf(0, left)
  vim.cmd('diffthis')

  vim.cmd('vsplit')
  local right = make_scratch('b', right_lines)
  vim.api.nvim_win_set_buf(0, right)
  vim.cmd('diffthis')

  vim.cmd('wincmd h')
  vim.notify('JSON diff: formatted both inputs and enabled diff', vim.log.levels.INFO)
end

-- Format one entered JSON blob, notifying which side failed (cancel/empty or
-- invalid JSON) and returning nil so the caller can abort the whole flow.
local function format_side(text, label)
  if not text or vim.trim(text) == '' then
    vim.notify('JSON diff cancelled — ' .. label .. ' was empty', vim.log.levels.WARN)
    return nil
  end
  local formatted, err = format_json(text)
  if not formatted then
    vim.notify('JSON diff: ' .. label .. ' ' .. err, vim.log.levels.ERROR)
    return nil
  end
  return formatted
end

--- Prompt for two JSON blobs one at a time via floating text-area inputs, then
--- format both and open them side-by-side in a new tab in diff mode. Cancelling
--- or leaving either input empty aborts the flow.
function M.diff_from_input()
  ui_utils.multiline_input({ title = 'JSON A (Esc to confirm)' }, function(text_a)
    local left = format_side(text_a, 'JSON A')
    if not left then return end

    ui_utils.multiline_input({ title = 'JSON B (Esc to confirm)' }, function(text_b)
      local right = format_side(text_b, 'JSON B')
      if not right then return end
      open_diff(left, right)
    end)
  end)
end

return M
