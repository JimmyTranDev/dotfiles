local ui_utils = require('custom.utils.ui')
local async = require('custom.utils.async')
local files = require('custom.utils.files')

local M = {}

local function get_org_dirs()
  local programming_dir = vim.fn.expand('~/Programming')
  local dirs = {}
  for _, entry in ipairs(files.scan(programming_dir, { type = 'directory', hidden = true })) do
    dirs[#dirs + 1] = entry.name
  end
  table.sort(dirs)
  return dirs
end

local function get_repo_dirs(org)
  local org_path = vim.fn.expand('~/Programming') .. '/' .. org
  local dirs = {}
  for _, entry in ipairs(files.scan(org_path, { type = 'directory', hidden = true })) do
    dirs[#dirs + 1] = entry.name
  end
  table.sort(dirs)
  return dirs
end

local function link_package()
  local orgs = get_org_dirs()
  if #orgs == 0 then
    vim.notify('No directories found in ~/Programming', vim.log.levels.WARN)
    return
  end

  ui_utils.safe_select(orgs, {
    prompt = 'Select organization:',
  }, function(selected_org)
    local repos = get_repo_dirs(selected_org)
    if #repos == 0 then
      vim.notify('No repositories found in ' .. selected_org, vim.log.levels.WARN)
      return
    end

    ui_utils.safe_select(repos, {
      prompt = 'Select repository to link:',
    }, function(selected_repo)
      local target_path = vim.fn.expand('~/Programming') .. '/' .. selected_org .. '/' .. selected_repo
      vim.notify('Running: pnpm link ' .. target_path, vim.log.levels.INFO)
      async.run_cmd({ 'pnpm', 'link', target_path }, function(res)
        if res.code == 0 then
          vim.notify('Linked ' .. selected_org .. '/' .. selected_repo, vim.log.levels.INFO)
        else
          vim.notify('Failed to link ' .. selected_org .. '/' .. selected_repo, vim.log.levels.ERROR)
        end
      end, { cwd = vim.fn.getcwd() })
    end)
  end)
end

local function get_linked_packages(callback)
  async.run_cmd({ 'pnpm', 'ls', '--json', '--depth', '0' }, function(res)
    local output = res.stdout or ''
    if output == '' then
      callback({})
      return
    end

    local ok, parsed = pcall(vim.json.decode, output)
    if not ok or not parsed then
      callback({})
      return
    end

    local entries = type(parsed) == 'table' and parsed[1] or parsed
    local deps = entries and entries.dependencies or {}
    local dev_deps = entries and entries.devDependencies or {}

    local linked = {}
    for name, info in pairs(deps) do
      if info.link then table.insert(linked, { name = name, path = info.path or info.version }) end
    end
    for name, info in pairs(dev_deps) do
      if info.link then table.insert(linked, { name = name, path = info.path or info.version }) end
    end

    table.sort(linked, function(a, b) return a.name < b.name end)
    callback(linked)
  end, { cwd = vim.fn.getcwd() })
end

local function unlink_package()
  get_linked_packages(function(linked)
    if #linked == 0 then
      vim.notify('No linked packages found', vim.log.levels.INFO)
      return
    end

    local items = {}
    for _, pkg in ipairs(linked) do
      table.insert(items, {
        name = pkg.name .. ' -> ' .. (pkg.path or '?'),
        pkg_name = pkg.name,
      })
    end

    ui_utils.safe_select(items, {
      prompt = 'Select package to unlink:',
      format_item = function(item) return item.name end,
    }, function(selected)
      vim.notify('Running: pnpm unlink ' .. selected.pkg_name, vim.log.levels.INFO)
      async.run_cmd({ 'pnpm', 'unlink', selected.pkg_name }, function(res)
        if res.code == 0 then
          vim.notify('Unlinked ' .. selected.pkg_name, vim.log.levels.INFO)
        else
          vim.notify('Failed to unlink ' .. selected.pkg_name, vim.log.levels.ERROR)
        end
      end, { cwd = vim.fn.getcwd() })
    end)
  end)
end

function M.pnpm_link() link_package() end

function M.pnpm_unlink() unlink_package() end

return M
