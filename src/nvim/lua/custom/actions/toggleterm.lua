local M = {}

local label_windows = {}

function M.create_kill_toggle_term(index)
  return function()
    local term = require('toggleterm.terminal').get_all()[index]
    if term then term:shutdown() end
  end
end

function M.kill_all_toggle_term()
  for _, term in pairs(require('toggleterm.terminal').get_all()) do
    term:shutdown()
  end
end

local function close_label(term_id)
  local win = label_windows[term_id]
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end
  label_windows[term_id] = nil
end

local function show_label(term_id, term_win)
  close_label(term_id)
  if not vim.api.nvim_win_is_valid(term_win) then return end

  local label = tostring(term_id)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { ' ' .. label .. ' ' })

  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'win',
    win = term_win,
    anchor = 'NE',
    width = #label + 2,
    height = 1,
    row = 0,
    col = vim.api.nvim_win_get_width(term_win),
    style = 'minimal',
    border = 'rounded',
    focusable = false,
    zindex = 50,
  })

  vim.wo[win].winhl = 'Normal:DiagnosticInfo,FloatBorder:DiagnosticInfo'
  label_windows[term_id] = win
end

function M.setup_floating_labels()
  vim.api.nvim_create_autocmd('TermOpen', {
    group = vim.api.nvim_create_augroup('toggleterm_labels', { clear = true }),
    pattern = 'term://*toggleterm#*',
    callback = function()
      vim.schedule(function()
        local bufname = vim.api.nvim_buf_get_name(0)
        local term_id = tonumber(bufname:match('#(%d+)$'))
        if not term_id then return end
        local win = vim.api.nvim_get_current_win()
        show_label(term_id, win)
      end)
    end,
  })

  vim.api.nvim_create_autocmd('TermClose', {
    group = vim.api.nvim_create_augroup('toggleterm_labels_close', { clear = true }),
    pattern = 'term://*toggleterm#*',
    callback = function()
      local bufname = vim.api.nvim_buf_get_name(0)
      local term_id = tonumber(bufname:match('#(%d+)$'))
      if term_id then close_label(term_id) end
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = vim.api.nvim_create_augroup('toggleterm_labels_winclosed', { clear = true }),
    callback = function()
      for term_id, win in pairs(label_windows) do
        if not vim.api.nvim_win_is_valid(win) then
          label_windows[term_id] = nil
        end
      end
    end,
  })
end

function M.get_next_free_terminal(start_id)
  local terminals = require('toggleterm.terminal')
  local id = start_id or 1
  for _ = 1, 20 do
    local term = terminals.get(id)
    if not term or not term:is_open() then
      return id
    end
    id = id + 1
  end
  return id
end

return M
