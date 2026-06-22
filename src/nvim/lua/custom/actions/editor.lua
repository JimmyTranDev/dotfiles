local async = require('custom.utils.async')
local files = require('custom.utils.files')

local M = {}

function M.toggle_spellcheck() vim.cmd('set spell!') end

function M.toggle_wrap() vim.opt.wrap = not vim.opt.wrap:get() end

function M.toggle_markview() vim.cmd('Markview Toggle') end

-- Maximize the current window by opening its buffer in a dedicated full-size
-- tab (`:tab split`); toggling again closes that tab, restoring the original
-- split layout exactly. The cursor position from the maximized view is synced
-- back to the source window on restore.
function M.toggle_maximize()
  local ok, zoomed = pcall(vim.api.nvim_tabpage_get_var, 0, 'zoom_maximized')
  if ok and zoomed then
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.cmd('tabclose')
    pcall(vim.api.nvim_win_set_cursor, 0, cursor)
    return
  end

  if #vim.api.nvim_tabpage_list_wins(0) < 2 then
    vim.notify('Only one window — already maximized', vim.log.levels.INFO)
    return
  end

  vim.cmd('tab split')
  vim.api.nvim_tabpage_set_var(0, 'zoom_maximized', true)
end

local function scan_dirs(dir)
  local names = {}
  for _, entry in ipairs(files.scan(dir, { type = 'directory' })) do
    names[#names + 1] = entry.name
  end
  return names
end

local function open_project_readme(target_dir)
  local candidates = { 'README.md', 'README.markdown', 'README.txt', 'README' }
  for _, candidate in ipairs(candidates) do
    local path = target_dir .. '/' .. candidate
    if vim.uv.fs_stat(path) then
      vim.cmd('edit ' .. vim.fn.fnameescape(path))
      return
    end
  end
end

function M.switch_repo_by_zellij_tab()
  if not vim.env.ZELLIJ then
    vim.notify('Not running inside a Zellij session', vim.log.levels.ERROR)
    return
  end

  local base_dir = vim.fn.expand('~/Programming')
  local entries = {}

  for _, org in ipairs(scan_dirs(base_dir)) do
    local org_dir = base_dir .. '/' .. org
    for _, repo in ipairs(scan_dirs(org_dir)) do
      table.insert(entries, { label = org .. '/' .. repo, dir = org_dir .. '/' .. repo, name = repo })
    end
  end

  table.sort(entries, function(a, b) return a.label < b.label end)

  if #entries == 0 then
    vim.notify('No repos found in ' .. base_dir, vim.log.levels.WARN)
    return
  end

  vim.ui.select(entries, {
    prompt = 'Switch to repo:',
    format_item = function(item) return item.label end,
  }, function(selected)
    if not selected then return end

    local target_dir = selected.dir
    vim.cmd('cd ' .. vim.fn.fnameescape(target_dir))
    vim.cmd('tcd ' .. vim.fn.fnameescape(target_dir))

    open_project_readme(target_dir)

    async.run_cmd({ 'zellij', 'action', 'rename-tab', selected.name }, function(result)
      if result.code ~= 0 then
        vim.notify('Switched to ' .. selected.name .. ' but failed to rename tab', vim.log.levels.WARN)
      else
        vim.notify('Switched to: ' .. selected.name, vim.log.levels.INFO)
      end
    end)
  end)
end

return M
