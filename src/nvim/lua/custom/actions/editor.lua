local M = {}

function M.toggle_spellcheck() vim.cmd('set spell!') end

function M.toggle_wrap() vim.opt.wrap = not vim.opt.wrap:get() end

function M.toggle_markview() vim.cmd('Markview Toggle') end

local function scan_dirs(dir)
  local names = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return names end

  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if entry_type == 'directory' and not name:match('^%.') then
      table.insert(names, name)
    end
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

    vim.system(
      { 'zellij', 'action', 'rename-tab', selected.name },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code ~= 0 then
          vim.notify('Switched to ' .. selected.name .. ' but failed to rename tab', vim.log.levels.WARN)
        else
          vim.notify('Switched to: ' .. selected.name, vim.log.levels.INFO)
        end
      end)
    )
  end)
end

return M
