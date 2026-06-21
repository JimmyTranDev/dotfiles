local M = {}

local function get_package_json_packages()
  local package_json_path = vim.fn.getcwd() .. '/package.json'
  local file = io.open(package_json_path, 'r')
  if not file then return nil end

  local content = file:read('*a')
  file:close()

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data then return nil end

  local packages = {}
  local function add_packages(deps, dep_type)
    if deps then
      for name, version in pairs(deps) do
        table.insert(packages, {
          name = name,
          version = version,
          type = dep_type,
          text = name .. ' @ ' .. version .. ' (' .. dep_type .. ')',
        })
      end
    end
  end

  add_packages(data.dependencies, 'dependencies')
  add_packages(data.devDependencies, 'devDependencies')
  add_packages(data.peerDependencies, 'peerDependencies')
  add_packages(data.optionalDependencies, 'optionalDependencies')

  table.sort(packages, function(a, b) return a.name < b.name end)
  return packages
end

local DEP_TYPE_HL = {
  dependencies = 'DiagnosticOk',
  devDependencies = 'DiagnosticInfo',
  peerDependencies = 'DiagnosticWarn',
  optionalDependencies = 'DiagnosticHint',
}

local function format_package_item(item)
  local type_hl = DEP_TYPE_HL[item.type] or 'Normal'
  return {
    { item.name, type_hl },
    { ' @ ', 'Comment' },
    { item.version, 'String' },
    { ' (' .. item.type .. ')', 'Comment' },
  }
end

function M.show_package_json_picker()
  local packages = get_package_json_packages()
  if not packages then
    vim.notify('No package.json found in current directory', vim.log.levels.WARN)
    return
  end

  if #packages == 0 then
    vim.notify('No packages found in package.json', vim.log.levels.INFO)
    return
  end

  Snacks.picker({
    title = 'Package.json Packages',
    items = packages,
    preview = function(ctx)
      local pkg_path = vim.fn.getcwd() .. '/package.json'
      local pkg_lines = vim.fn.readfile(pkg_path)
      vim.api.nvim_buf_set_lines(ctx.buf, 0, -1, false, pkg_lines)
      vim.bo[ctx.buf].filetype = 'json'
      for i, line in ipairs(pkg_lines) do
        if line:find('"' .. ctx.item.name .. '"') then
          vim.api.nvim_win_set_cursor(ctx.win, { i, 0 })
          break
        end
      end
    end,
    format = function(item) return format_package_item(item) end,
    confirm = function(picker, item)
      picker:close()
      local actions = {
        { name = 'Update to latest', value = 'update' },
        { name = 'Delete package', value = 'delete' },
        { name = 'Open on npm', value = 'npm' },
        { name = 'Cancel', value = 'cancel' },
      }

      vim.ui.select(actions, {
        prompt = 'Action for ' .. item.name .. ':',
        format_item = function(a) return a.name end,
      }, function(action)
        if not action or action.value == 'cancel' then return end

        if action.value == 'update' then
          local cmd = 'npm install ' .. item.name .. '@latest'
          if item.type == 'devDependencies' then cmd = cmd .. ' --save-dev' end
          vim.notify('Running: ' .. cmd, vim.log.levels.INFO)
          vim.fn.jobstart(cmd, {
            on_exit = function(_, code)
              if code == 0 then
                vim.notify('Updated ' .. item.name .. ' to latest', vim.log.levels.INFO)
              else
                vim.notify('Failed to update ' .. item.name, vim.log.levels.ERROR)
              end
            end,
          })
        elseif action.value == 'delete' then
          local cmd = 'npm uninstall ' .. item.name
          vim.notify('Running: ' .. cmd, vim.log.levels.INFO)
          vim.fn.jobstart(cmd, {
            on_exit = function(_, code)
              if code == 0 then
                vim.notify('Removed ' .. item.name, vim.log.levels.INFO)
              else
                vim.notify('Failed to remove ' .. item.name, vim.log.levels.ERROR)
              end
            end,
          })
        elseif action.value == 'npm' then
          vim.fn.system('open https://www.npmjs.com/package/' .. item.name)
        end
      end)
    end,
  })
end

return M
