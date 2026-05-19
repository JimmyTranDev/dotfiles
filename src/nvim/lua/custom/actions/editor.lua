local M = {}

function M.toggle_spellcheck() vim.cmd('set spell!') end

function M.toggle_wrap() vim.opt.wrap = not vim.opt.wrap:get() end

function M.toggle_markview() vim.cmd('Markview Toggle') end

function M.switch_repo_by_zellij_tab()
  if not vim.env.ZELLIJ then
    vim.notify('Not running inside a Zellij session', vim.log.levels.ERROR)
    return
  end

  local cwd = vim.fn.getcwd()
  local base_dir = vim.fn.fnamemodify(cwd, ':h')
  local entries = {}
  local handle = vim.uv.fs_scandir(base_dir)
  if not handle then
    vim.notify('Failed to scan ' .. base_dir, vim.log.levels.ERROR)
    return
  end

  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if entry_type == 'directory' and not name:match('^%.') then
      table.insert(entries, name)
    end
  end

  table.sort(entries)

  if #entries == 0 then
    vim.notify('No directories found in ' .. base_dir, vim.log.levels.WARN)
    return
  end

  vim.ui.select(entries, { prompt = 'Switch to repo:' }, function(selected)
    if not selected then return end

    local target_dir = base_dir .. '/' .. selected
    vim.cmd('cd ' .. vim.fn.fnameescape(target_dir))
    vim.cmd('tcd ' .. vim.fn.fnameescape(target_dir))

    vim.system(
      { 'zellij', 'action', 'rename-tab', selected },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          vim.notify('Switched to ' .. selected .. ' but failed to rename tab', vim.log.levels.WARN)
        else
          vim.notify('Switched to: ' .. selected, vim.log.levels.INFO)
        end
      end)
    )
  end)
end

return M
