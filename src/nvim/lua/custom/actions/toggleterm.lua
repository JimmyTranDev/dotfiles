local registry = require('custom.utils.terminal_registry')
local ui = require('custom.utils.ui')

local M = {}

function M.open_terminal_picker()
  local terminals = registry.list()
  if #terminals == 0 then
    vim.notify('No terminals running', vim.log.levels.INFO)
    return
  end

  local items = {}
  for _, info in ipairs(terminals) do
    local status_icon = info.is_open and '󰄬' or '󰄱'
    local cmd_text = info.cmd and (' (' .. info.cmd:sub(1, 50) .. ')') or ''
    table.insert(items, {
      text = status_icon .. ' ' .. info.name .. cmd_text,
      terminal_name = info.name,
    })
  end

  ui.pick({
    title = 'Terminals',
    items = items,
    format = function(item) return { { item.text } } end,
    on_confirm = function(item)
      if item then registry.toggle(item.terminal_name) end
    end,
    extra = {
      actions = {
        kill_terminal = function(picker, item)
          if item then
            registry.kill(item.terminal_name)
            picker:close()
            vim.schedule(function() M.open_terminal_picker() end)
          end
        end,
        kill_all_terminals = function(picker)
          picker:close()
          registry.kill_all()
          vim.notify('All terminals killed', vim.log.levels.INFO)
        end,
      },
      win = {
        input = {
          keys = {
            ['<C-x>'] = { 'kill_terminal', desc = 'Kill terminal', mode = { 'n', 'i' } },
            ['<C-a>'] = { 'kill_all_terminals', desc = 'Kill all terminals', mode = { 'n', 'i' } },
          },
        },
        list = {
          keys = {
            ['<C-x>'] = { 'kill_terminal', desc = 'Kill terminal', mode = { 'n' } },
            ['<C-a>'] = { 'kill_all_terminals', desc = 'Kill all terminals', mode = { 'n' } },
          },
        },
      },
    },
  })
end

function M.create_blank_terminal()
  local term = registry.create()
  term:toggle()
end

function M.kill_all_terminals()
  registry.kill_all()
  vim.notify('All terminals killed', vim.log.levels.INFO)
end

return M
