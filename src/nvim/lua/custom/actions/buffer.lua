local M = {}

local function is_real_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if not vim.bo[buf].buflisted then return false end
  local bt = vim.bo[buf].buftype
  return bt == '' or bt == 'acwrite'
end

local function get_listed_buffers()
  local bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if is_real_buffer(buf) then table.insert(bufs, buf) end
  end
  return bufs
end

local function get_most_relevant_buffer(current_buf)
  local bufs = get_listed_buffers()
  local candidates = {}
  for _, buf in ipairs(bufs) do
    if buf ~= current_buf then table.insert(candidates, buf) end
  end

  if #candidates == 0 then return nil end

  local lastused = {}
  for _, buf in ipairs(candidates) do
    local info = vim.fn.getbufinfo(buf)[1]
    lastused[buf] = info and info.lastused or 0
  end

  table.sort(candidates, function(a, b) return lastused[a] > lastused[b] end)

  return candidates[1]
end

local function close_orphan_splits()
  local wins = vim.api.nvim_tabpage_list_wins(0)
  if #wins <= 1 then return end

  local to_close = {}
  for _, win in ipairs(wins) do
    local buf = vim.api.nvim_win_get_buf(win)
    local name = vim.api.nvim_buf_get_name(buf)
    local bt = vim.bo[buf].buftype
    local listed = vim.bo[buf].buflisted
    local is_empty = name == '' and not listed and bt == ''
    local is_scratch = bt == 'nofile' and not listed

    if is_empty or is_scratch then table.insert(to_close, win) end
  end

  local remaining = #wins - #to_close
  if remaining < 1 then return end

  for _, win in ipairs(to_close) do
    if vim.api.nvim_win_is_valid(win) then pcall(vim.api.nvim_win_close, win, false) end
  end
end

function M.smart_close()
  local current_buf = vim.api.nvim_get_current_buf()

  if not is_real_buffer(current_buf) then
    local ok = pcall(vim.cmd, 'close')
    if not ok then vim.notify('Cannot close last window', vim.log.levels.WARN) end
    return
  end

  if vim.bo[current_buf].modified then
    vim.ui.select({ 'Save and close', 'Discard and close', 'Cancel' }, { prompt = 'Buffer has unsaved changes' }, function(choice)
      if choice == 'Save and close' then
        vim.cmd('write')
        M.smart_close()
      elseif choice == 'Discard and close' then
        vim.bo[current_buf].modified = false
        M.smart_close()
      end
    end)
    return
  end

  local target = get_most_relevant_buffer(current_buf)

  if target then
    vim.api.nvim_set_current_buf(target)
  else
    vim.cmd('enew')
  end

  pcall(vim.cmd, 'bdelete ' .. current_buf)
  close_orphan_splits()
end

function M.close_orphan_splits()
  close_orphan_splits()
  vim.notify('Cleaned orphan splits', vim.log.levels.INFO)
end

return M
