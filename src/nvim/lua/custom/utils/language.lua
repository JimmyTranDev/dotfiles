local link_constants = require('custom.constants.links')
local github_utils = require('custom.utils.github')
local file_utils = require('custom.utils.files')
local M = {}

function M.get_current_java_class()
  local current_file = vim.fn.expand('%')
  local current_class = vim.fn.substitute(current_file, '.*/src/main/java/', '', '')
  current_class = vim.fn.substitute(current_class, '/', '.', 'g')
  current_class = vim.fn.substitute(current_class, '\\.java', '', '')
  return current_class
end

local function find_workspace_root(start_path)
  local path = start_path or vim.fn.getcwd()
  local lockfiles = {
    { file = 'bun.lockb', manager = 'bun' },
    { file = 'bun.lock', manager = 'bun' },
    { file = 'pnpm-lock.yaml', manager = 'pnpm' },
    { file = 'yarn.lock', manager = 'yarn' },
    { file = 'package-lock.json', manager = 'npm' },
  }

  while path ~= '/' and path ~= '' do
    for _, lockfile in ipairs(lockfiles) do
      local full_path = path .. '/' .. lockfile.file
      if vim.fn.filereadable(full_path) == 1 then return path, lockfile.manager end
    end

    local parent = vim.fn.fnamemodify(path, ':h')
    if parent == path then break end
    path = parent
  end

  return nil, nil
end

local function is_workspace(root_path)
  if not root_path then return false end

  local workspace_files = {
    root_path .. '/pnpm-workspace.yaml',
    root_path .. '/lerna.json',
    root_path .. '/nx.json',
    root_path .. '/rush.json',
    root_path .. '/turbo.json',
    root_path .. '/.yarnrc.yml',
  }

  for _, file in ipairs(workspace_files) do
    if vim.fn.filereadable(file) == 1 then return true end
  end

  local package_json_path = root_path .. '/package.json'
  if vim.fn.filereadable(package_json_path) == 1 then
    local ok, package_json = pcall(vim.json.decode, table.concat(vim.fn.readfile(package_json_path), '\n'))
    if ok and package_json and package_json.workspaces then return true end
  end

  return false
end

function M.get_workspace_root()
  local root_path, _ = find_workspace_root()
  return root_path
end

function M.get_javascript_package_manager()
  local root_path, package_manager = find_workspace_root()

  if package_manager then
    if is_workspace(root_path) then return package_manager end

    return package_manager
  end

  if vim.fn.filereadable('bun.lockb') == 1 then
    return 'bun'
  elseif vim.fn.filereadable('bun.lock') == 1 then
    return 'bun'
  elseif vim.fn.filereadable('yarn.lock') == 1 then
    return 'yarn'
  elseif vim.fn.filereadable('package-lock.json') == 1 then
    return 'npm'
  elseif vim.fn.filereadable('pnpm-lock.yaml') == 1 then
    return 'pnpm'
  end

  return ''
end

local DEV_ARG = {
  yarn = '--dev',
  npm = '--save-dev',
  pnpm = '--save-dev',
  bun = '--dev',
}

local NPX_EQUIVALENT = {
  yarn = 'yarn dlx',
  pnpm = 'pnpm dlx',
  bun = 'bunx',
}

function M.get_javascript_package_manager_dev_arg() return DEV_ARG[M.get_javascript_package_manager()] end

function M.get_npx_equivalent() return NPX_EQUIVALENT[M.get_javascript_package_manager()] or 'npx' end

function M.list_package_json_commands()
  local scripts = {}

  local current_package_json = vim.fn.getcwd() .. '/package.json'
  if vim.fn.filereadable(current_package_json) == 1 then
    local current_scripts = M.get_scripts_from_package_json(current_package_json)
    if current_scripts and #current_scripts > 0 then scripts = current_scripts end
  end

  if #scripts == 0 then
    local workspace_root = M.get_workspace_root()
    if workspace_root then
      local root_package_json = workspace_root .. '/package.json'
      if vim.fn.filereadable(root_package_json) == 1 then
        local root_scripts = M.get_scripts_from_package_json(root_package_json)
        if root_scripts then scripts = root_scripts end
      end
    end
  end

  return scripts
end

function M.get_scripts_from_package_json(package_json_path)
  local result = vim.fn.system("jq '.scripts | keys_unsorted' " .. package_json_path)
  if vim.v.shell_error ~= 0 then return {} end
  local ok, scripts = pcall(vim.json.decode, result)
  if ok and scripts then return scripts end
  return {}
end

function M.open_server_url(type)
  local project_names = { github_utils.get_repo_name() }
  vim.list_extend(project_names, link_constants.project_names)
  vim.ui.select(project_names, {
    prompt = 'Select repo to open:',
  }, function(project_name)
    if project_name == nil then return end

    local routes = link_constants.project_name_to_route_object[project_name]
    if not routes then
      vim.notify('No routes found for project: ' .. project_name, vim.log.levels.WARN)
      return
    end
    local url = routes[type]
    if url == nil then
      vim.notify('No url found for type ' .. type .. ' of project: ' .. project_name, vim.log.levels.WARN)
      return
    end
    file_utils.open(url)
  end)
end

return M
