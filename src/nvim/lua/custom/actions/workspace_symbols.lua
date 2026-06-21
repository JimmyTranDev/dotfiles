local M = {}

function M.show_workspace_symbols_with_cache()
  local cache = require('custom.utils.workspace_symbol_cache')
  local cached = cache.get(300)
  if cached then
    return Snacks.picker({
      title = 'LSP Workspace Symbols (Cached)',
      items = cached,
      preview = 'file',
      format = function(item)
        local kind = item.kind or ''
        local name = item.name or ''
        local file = item.file or ''
        return {
          { kind .. ' ', 'Type' },
          { name .. ' ', 'Normal' },
          { vim.fn.fnamemodify(file, ':~:.'), 'Comment' },
        }
      end,
      confirm = function(picker, item)
        picker:close()
        if item.file and item.pos then
          vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
          pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] })
        end
      end,
    })
  end

  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf, method = 'workspace/symbol' })
  if #clients == 0 then
    Snacks.picker.lsp_workspace_symbols()
    return
  end

  local all_items = {}
  local pending = #clients

  for _, client in ipairs(clients) do
    client:request('workspace/symbol', { query = '' }, function(err, result)
      if not err and result then
        local lsp_mod = require('snacks.picker.source.lsp')
        local items = lsp_mod.results_to_items(client, result, { text_with_file = true })
        for _, item in ipairs(items) do
          table.insert(all_items, {
            text = item.text,
            file = item.file,
            pos = item.pos,
            kind = item.kind,
            name = item.name,
          })
        end
      end

      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          if #all_items > 0 then cache.set(all_items) end
          Snacks.picker({
            title = 'LSP Workspace Symbols',
            items = all_items,
            preview = 'file',
            format = function(item)
              local kind = item.kind or ''
              local name = item.name or ''
              local file = item.file or ''
              return {
                { kind .. ' ', 'Type' },
                { name .. ' ', 'Normal' },
                { vim.fn.fnamemodify(file, ':~:.'), 'Comment' },
              }
            end,
            confirm = function(picker, item)
              picker:close()
              if item.file and item.pos then
                vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
                pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] })
              end
            end,
          })
        end)
      end
    end, buf)
  end
end

return M
