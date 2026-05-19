local M = {}

function M.show_keybinding_stats()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return vim.notify('Snacks not available', vim.log.levels.WARN) end

  local tracker = require('custom.utils.keybinding_tracker')
  local raw_stats = tracker.get_stats()

  local items = {}
  for _, entry in pairs(raw_stats) do
    local last_used = entry.last_used > 0 and os.date('%Y-%m-%d %H:%M', entry.last_used) or 'never'
    local text = string.format('[%s] %-25s  count: %-6d  last: %s', entry.mode, entry.lhs, entry.count, last_used)
    table.insert(items, {
      text = text,
      mode = entry.mode,
      lhs = entry.lhs,
      count = entry.count,
      last_used = entry.last_used,
      idx = #items + 1,
    })
  end

  table.sort(items, function(a, b) return a.count > b.count end)

  for i, item in ipairs(items) do
    item.idx = i
  end

  if #items == 0 then return vim.notify('No keybinding stats recorded yet', vim.log.levels.INFO) end

  snacks.picker({
    title = 'Keybinding Usage Stats (' .. #items .. ' keymaps)',
    items = items,
    format = function(item)
      local rank = string.format('%3d. ', item.idx)
      local mode_display = string.format('[%s]', item.mode)
      local count_display = string.format('%d uses', item.count)
      local last_display = item.last_used > 0 and os.date('%m-%d %H:%M', item.last_used) or 'never'
      return {
        { rank, 'LineNr' },
        { mode_display, 'Special' },
        { ' ' },
        { string.format('%-25s', item.lhs), 'Function' },
        { ' ' },
        { count_display, 'Number' },
        { '  last: ', 'Comment' },
        { last_display, 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.notify(
        string.format(
          'Keymap %s [%s]: used %d times, last used %s',
          item.lhs,
          item.mode,
          item.count,
          item.last_used > 0 and os.date('%Y-%m-%d %H:%M:%S', item.last_used) or 'never'
        ),
        vim.log.levels.INFO
      )
    end,
  })
end

function M.reset_keybinding_stats()
  vim.ui.select({ 'Yes', 'No' }, { prompt = 'Reset all keybinding stats?' }, function(choice)
    if choice == 'Yes' then
      require('custom.utils.keybinding_tracker').reset_stats()
      vim.notify('Keybinding stats reset', vim.log.levels.INFO)
    end
  end)
end

return M
