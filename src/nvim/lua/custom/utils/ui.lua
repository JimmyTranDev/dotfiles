local M = {}

local panel_ns = vim.api.nvim_create_namespace('custom_panel')

function M.safe_select(items, opts, callback)
  if not items or #items == 0 then
    vim.notify('No items available for selection', vim.log.levels.WARN)
    return
  end
  if not callback then error('Callback function is required') end

  local on_back = opts and opts.on_back
  local select_opts = vim.tbl_extend('force', opts or {}, {})
  select_opts.on_back = nil

  if on_back then
    select_opts.snacks = {
      actions = {
        back = function(picker)
          picker:close()
          vim.schedule(on_back)
        end,
        confirm_right = function(picker, item)
          if item then
            picker:close()
            vim.schedule(function() callback(item.item) end)
          end
        end,
      },
      win = {
        input = {
          keys = {
            ['<Left>'] = { 'back', mode = { 'n', 'i' } },
            ['<Right>'] = { 'confirm_right', mode = { 'n', 'i' } },
          },
        },
        list = {
          keys = {
            ['<Left>'] = { 'back', mode = { 'n' } },
            ['<Right>'] = { 'confirm_right', mode = { 'n' } },
          },
        },
      },
    }
  end

  vim.ui.select(items, select_opts, function(selected)
    if selected then callback(selected) end
  end)
end

function M.safe_input(opts, validator, callback)
  if type(validator) == 'function' and not callback then
    callback = validator
    validator = nil
  end
  if not callback then error('Callback function is required') end

  vim.ui.input(opts, function(input)
    if not input or input == '' then return end
    if validator then
      local is_valid, error_msg = validator(input)
      if not is_valid then
        vim.notify(error_msg or 'Invalid input', vim.log.levels.WARN)
        return
      end
    end
    callback(input)
  end)
end

M.show_success = function(msg) vim.notify(msg, vim.log.levels.INFO) end

function M.exec_in_terminal(cmd, label, opts)
  if not cmd then error('Command is required') end
  local registry = require('custom.utils.terminal_registry')
  local name
  if type(opts) == 'number' then
    name = label or ('terminal-' .. opts)
  elseif type(opts) == 'table' then
    name = opts.name or label
  else
    name = label
  end
  name = name or cmd
  registry.get_or_create(name, { cmd = cmd })
  if label then vim.defer_fn(function() vim.notify(label, vim.log.levels.INFO) end, 500) end
end

function M.multiline_input(opts, callback)
  if not callback then error('Callback function is required') end
  local title = (opts and opts.title) or 'Input'
  local width = math.min(80, math.floor(vim.o.columns * 0.6))
  local height = math.min(20, math.floor(vim.o.lines * 0.4))
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
    footer = ' <Esc> confirm | <leader>w cancel ',
    footer_pos = 'center',
  })

  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'markdown'
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  local function close_and_return(lines)
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
    if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
    if lines then
      local text = table.concat(lines, '\n')
      if text ~= '' then
        vim.schedule(function() callback(text) end)
      else
        vim.schedule(function() callback(nil) end)
      end
    else
      vim.schedule(function() callback(nil) end)
    end
  end

  local leader = vim.g.mapleader or '\\'
  local confirm_lhs = leader .. 'w'

  vim.keymap.set('n', confirm_lhs, function() close_and_return(nil) end, { buffer = buf, nowait = true })

  vim.keymap.set('n', '<Esc>', function()
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    close_and_return(lines)
  end, { buffer = buf, nowait = true })

  vim.cmd('startinsert')
end

function M.add_back_option(options, text, value) table.insert(options, { name = '← ' .. text, is_back = true, value = value or '__back__' }) end

--- Show read-only lines in a centered floating panel.
--- Each entry in `lines` is { text } or { text, highlight_group }.
---@param opts { title: string, lines: ({ [1]: string, [2]?: string })[] }
---@return integer win
function M.show_panel(opts)
  local content, highlights = {}, {}
  for i, line in ipairs(opts.lines) do
    content[i] = line[1] or ''
    if line[2] then highlights[#highlights + 1] = { i - 1, line[2] } end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].buftype = 'nofile'

  local width = 60
  for _, l in ipairs(content) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 4)
  end
  width = math.min(width, math.floor(vim.o.columns * 0.8))
  local height = math.min(#content, math.floor(vim.o.lines * 0.6))

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. opts.title .. ' ',
    title_pos = 'center',
  })

  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_set_extmark(buf, panel_ns, hl[1], 0, { end_col = #content[hl[1] + 1], hl_group = hl[2] })
  end

  local function close()
    if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  end
  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true })
  return win
end

return M
