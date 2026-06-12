local language_utils = require('custom.utils.language')
local ui_utils = require('custom.utils.ui')
local async_utils = require('custom.utils.async')
local validation = require('custom.utils.validation')

local M = {}

local function get_pm()
  local pm = language_utils.get_javascript_package_manager()
  if not pm or pm == '' then
    vim.notify('No JavaScript package manager found', vim.log.levels.ERROR)
    return nil
  end
  return pm
end

function M.run_project_jar()
  local cwd = vim.fn.getcwd()

  if vim.fn.filereadable(cwd .. '/pom.xml') ~= 1 then
    vim.notify('No pom.xml found in cwd', vim.log.levels.ERROR)
    return
  end

  local function find_app_modules()
    local modules = {}
    local entries = vim.fn.readdir(
      cwd,
      function(name) return vim.fn.isdirectory(cwd .. '/' .. name) == 1 and vim.fn.filereadable(cwd .. '/' .. name .. '/pom.xml') == 1 end
    )
    for _, name in ipairs(entries) do
      table.insert(modules, name)
    end
    return modules
  end

  local function run_with_module(module)
    local jar_path = module and (module .. '/target/' .. module .. '.jar') or ('target/' .. vim.fn.fnamemodify(cwd, ':t') .. '.jar')
    local label = module or vim.fn.fnamemodify(cwd, ':t')
    local cmd = 'mvn clean package -Dmaven.gitcommitid.skip=true -Dmaven.test.skip=true'
      .. ' && java -jar'
      .. ' -Dspring.profiles.active=local'
      .. ' -Dspring.cloud.gcp.sql.enabled=false'
      .. ' '
      .. jar_path
    ui_utils.exec_in_terminal(cmd, 'Spring Boot: ' .. label, { name = 'spring-boot' })
  end

  local modules = find_app_modules()
  if #modules == 0 then
    run_with_module(nil)
    return
  end

  if #modules == 1 then
    run_with_module(modules[1])
    return
  end

  ui_utils.safe_select(modules, { prompt = 'Select module:' }, function(selected) run_with_module(selected) end)
end

function M.run_java_class_maven()
  local class = language_utils.get_current_java_class()
  if not class or class == '' then
    vim.notify('No Java class found', vim.log.levels.WARN)
    return
  end
  ui_utils.exec_in_terminal('mvn compile', 'Maven compile started', { name = 'mvn-compile' })
  ui_utils.exec_in_terminal('mvn exec:java -Dexec.mainClass=' .. class, 'Running: ' .. class, { name = 'mvn-exec' })
end

function M.run_java_class_javac()
  local class = language_utils.get_current_java_class()
  if not class or class == '' then
    vim.notify('No Java class found', vim.log.levels.WARN)
    return
  end
  vim.cmd(('terminal javac %s; java %s'):format(class, class))
end

function M.serve_markdown_folder()
  local folder = vim.fn.expand('%:p:h')
  if folder == '' then
    vim.notify('Could not determine current folder', vim.log.levels.ERROR)
    return
  end
  ui_utils.exec_in_terminal(('cd "%s" && markserv -b -p 5454'):format(folder), 'Markdown server started', { name = 'markserv' })
end

function M.compile_mjml_file()
  local file = vim.fn.expand('%')
  if not file:match('%.mjml$') then
    vim.notify('Not an MJML file', vim.log.levels.WARN)
    return
  end
  vim.cmd('!mjml -r "' .. file .. '" -o "' .. file:gsub('%.mjml$', '.html') .. '"')
  vim.cmd('!mjml -r "' .. file .. '" -o "' .. file:gsub('%.mjml$', '.ftlh') .. '"')
  ui_utils.show_success('MJML compiled')
end

function M.install_javascript_package()
  local pm = get_pm()
  if not pm then return end

  local types = { 'production', 'development' }
  ui_utils.safe_select(types, { prompt = 'Package type:' }, function(pkg_type)
    ui_utils.safe_input({ prompt = 'Package name: ' }, function(pkg_name)
      if not validation.string(pkg_name, 1) then
        vim.notify('Invalid package name', vim.log.levels.ERROR)
        return
      end
      local cmd = pm .. ' add ' .. pkg_name
      if pkg_type == 'development' then cmd = cmd .. ' ' .. language_utils.get_javascript_package_manager_dev_arg() end
      ui_utils.exec_in_terminal(cmd, 'Installing: ' .. pkg_name, { name = 'npm-install' })
    end)
  end)
end

function M.run_package_script()
  local scripts = language_utils.list_package_json_commands()
  if #scripts > 0 then
    ui_utils.safe_select(scripts, { prompt = 'Select script:' }, function(script)
      local pm = get_pm()
      if pm then ui_utils.exec_in_terminal(pm .. ' ' .. script, 'Running: ' .. script, { name = 'npm-' .. script }) end
    end)
    return
  end

  if vim.fn.filereadable('Makefile') == 1 then
    local targets = {}
    local ok, iter = pcall(io.lines, 'Makefile')
    if ok then
      for line in iter do
        local target = line:match('^(%w[%w-_%.]*)%s*:')
        if target and target ~= 'PHONY' then table.insert(targets, target) end
      end
    end

    if #targets > 0 then
      local registry = require('custom.utils.terminal_registry')
      ui_utils.safe_select(targets, { prompt = 'Make target:' }, function(target)
        registry.get_or_create('make-' .. target, { cmd = 'make ' .. target })
      end)
      return
    end
  end

  vim.notify('No package.json or Makefile found', vim.log.levels.WARN)
end

function M.run_multiple_package_scripts()
  return function()
    local scripts = language_utils.list_package_json_commands()
    if #scripts == 0 then
      vim.notify('No scripts found in package.json', vim.log.levels.WARN)
      return
    end

    local pm = get_pm()
    if not pm then return end

    local max_splits = 6
    local items = {}
    for _, script in ipairs(scripts) do
      table.insert(items, { text = script, script = script })
    end

    local ok, snacks = pcall(require, 'snacks')
    if not ok then
      vim.notify('Snacks not available', vim.log.levels.ERROR)
      return
    end

    snacks.picker({
      title = 'Select npm scripts (multi-select with Tab)',
      items = items,
      format = function(item) return { { item.text } } end,
      multi = true,
      confirm = function(picker, selected)
        picker:close()
        if not selected or #selected == 0 then return end

        if #selected > max_splits then vim.notify('Capped to ' .. max_splits .. ' scripts (selected ' .. #selected .. ')', vim.log.levels.WARN) end

        local registry = require('custom.utils.terminal_registry')
        local count = math.min(#selected, max_splits)
        for i = 1, count do
          local script = selected[i].script
          registry.get_or_create('npm-run-' .. script, {
            cmd = pm .. ' run ' .. script,
            close_on_exit = false,
          })
        end
      end,
    })
  end
end

function M.kill_multiple_package_script_terms()
  return function()
    local registry = require('custom.utils.terminal_registry')
    local terminals = registry.list()
    local killed = 0
    for _, info in ipairs(terminals) do
      if info.name:match('^npm%-run%-') then
        registry.kill(info.name)
        killed = killed + 1
      end
    end
    vim.notify('Killed ' .. killed .. ' npm script terminals', vim.log.levels.INFO)
  end
end

function M.create_package_command_runner(command, should_exit)
  return function()
    local pm = get_pm()
    if not pm or not command then return end
    local registry = require('custom.utils.terminal_registry')
    local full_cmd = pm .. ' ' .. command
    if should_exit then
      full_cmd = full_cmd .. ' && exit'
    end
    registry.get_or_create('npm-' .. command:gsub('%s+', '-'), { cmd = full_cmd, close_on_exit = should_exit })
  end
end

function M.run_eslint_picker()
  ui_utils.show_success('Running ESLint...')
  local npx = language_utils.get_npx_equivalent()
  local output = vim.fn.system(npx .. ' eslint . --ext ts,tsx,js,jsx --format stylish 2>&1')

  local files = {}
  for line in output:gmatch('[^\r\n]+') do
    local path = line:match('^([^%s].+%.tsx?)$') or line:match('^([^%s].+%.jsx?)$')
    if path then files[path] = true end
  end

  local items = {}
  for path in pairs(files) do
    table.insert(items, { text = vim.fn.fnamemodify(path, ':~'), file = path })
  end

  if #items == 0 then
    ui_utils.show_success('No ESLint issues found')
    return
  end

  local ok, snacks = pcall(require, 'snacks')
  if not ok then return end

  snacks.picker({
    title = 'ESLint Results',
    items = items,
    preview = 'file',
    format = function(item)
      local icon, hl = snacks.util.icon(item.file, 'file')
      return { { icon, hl }, { ' ' }, { item.text } }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
    end,
  })
end

local function run_knip(args, _title, process_result)
  local pm = get_pm()
  if not pm then return end

  local cmd = pm .. ' dlx knip ' .. args
  ui_utils.show_success('Running knip...')

  async_utils.run(cmd, function(output, code)
    if output == '' then
      vim.notify('No issues found', vim.log.levels.INFO)
      return
    end

    local ok, result = pcall(vim.fn.json_decode, output)
    if not ok or not result then
      if code == 0 then
        ui_utils.show_success('Knip completed:\n' .. output:sub(1, 300))
      else
        vim.notify('Failed to parse output', vim.log.levels.ERROR)
      end
      return
    end

    process_result(result)
  end, function(_, err, code) vim.notify(('Knip failed (code %d): %s'):format(code, err), vim.log.levels.ERROR) end)
end

local function show_knip_picker(items, title)
  if #items == 0 then
    vim.notify('No issues found', vim.log.levels.INFO)
    return
  end

  local ok, snacks = pcall(require, 'snacks')
  if not ok then return end

  snacks.picker({
    title = title,
    items = items,
    preview = 'file',
    format = function(item)
      local icon, hl = snacks.util.icon(item.file or '', 'file')
      return { { icon, hl }, { ' ' }, { item.text } }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
      if item.line then vim.api.nvim_win_set_cursor(0, { item.line, 0 }) end
    end,
  })
  ui_utils.show_success(('Found %d issues'):format(#items))
end

function M.run_knip_unused_files()
  run_knip('--reporter json', 'Knip Unused Files', function(result)
    local items = {}
    for _, file in ipairs(result.files or {}) do
      table.insert(items, { file = file, line = 1, pos = { 1, 0 }, text = file .. ' (orphaned)' })
    end
    show_knip_picker(items, 'Knip Unused Files')
  end)
end

function M.run_knip_unused_code()
  run_knip('--reporter json', 'Knip Unused Code', function(result)
    local items = {}
    for _, issue in ipairs(result.issues or {}) do
      local file = issue.file
      for _, export in ipairs(issue.exports or {}) do
        table.insert(items, { file = file, line = export.line or 1, pos = { export.line or 1, 0 }, text = ('%s:%d - export: %s'):format(file, export.line or 1, export.name or '?') })
      end
      for _, typ in ipairs(issue.types or {}) do
        table.insert(items, { file = file, line = typ.line or 1, pos = { typ.line or 1, 0 }, text = ('%s:%d - type: %s'):format(file, typ.line or 1, typ.name or '?') })
      end
    end
    show_knip_picker(items, 'Knip Unused Code')
  end)
end

function M.run_knip_fix()
  local pm = get_pm()
  if not pm then return end
  ui_utils.show_success('Running knip fix...')
  async_utils.run(
    pm .. ' dlx knip --fix --allow-remove-files',
    function(out) ui_utils.show_success('Knip fix completed' .. (out ~= '' and ':\n' .. out or '')) end,
    function(_, err, code) vim.notify(('Knip fix failed (code %d): %s'):format(code, err), vim.log.levels.ERROR) end
  )
end

function M.run_knip_fix_current_folder()
  local pm = get_pm()
  if not pm then return end
  local dir = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h:.')
  if dir == '' then dir = '.' end
  ui_utils.show_success('Knip fix for: ' .. dir)
  vim.fn.jobstart(pm .. ' dlx knip --fix', { on_exit = function() vim.notify('Knip fix completed for ' .. dir, vim.log.levels.INFO) end })
end

function M.fix_and_organize_typescript_imports()
  ui_utils.show_success('Finding TypeScript files...')
  local files = vim.fn.systemlist("find . -type f \\( -name '*.ts' -o -name '*.tsx' \\) -not -path '*/node_modules/*'")
  if #files == 0 then
    vim.notify('No TypeScript files found', vim.log.levels.WARN)
    return
  end

  local i = 1
  local function process_next()
    if i > #files then
      ui_utils.show_success(('Processed %d files'):format(#files))
      return
    end
    pcall(function()
      vim.cmd('edit ' .. vim.fn.fnameescape(files[i]))
      vim.lsp.buf.execute_command({
        command = '_typescript.organizeImports',
        arguments = { vim.api.nvim_buf_get_name(0) },
      })
      vim.defer_fn(function()
        vim.cmd('silent write')
        vim.cmd('bdelete')
        i = i + 1
        process_next()
      end, 300)
    end)
  end
  process_next()
end

function M.create_make_command_runner()
  return function()
    if vim.fn.filereadable('Makefile') == 0 then
      vim.notify('No Makefile found', vim.log.levels.ERROR)
      return
    end

    local targets = {}
    local ok, iter = pcall(io.lines, 'Makefile')
    if ok then
      for line in iter do
        local target = line:match('^(%w[%w-_%.]*)%s*:')
        if target and target ~= 'PHONY' then table.insert(targets, target) end
      end
    end

    local registry = require('custom.utils.terminal_registry')
    ui_utils.safe_select(targets, { prompt = 'Make target:' }, function(target)
      registry.get_or_create('make-' .. target, { cmd = 'make ' .. target })
    end)
  end
end

function M.create_npm_update_command(type)
  local npx = language_utils.get_npx_equivalent()
  local flags = { minor = ' -t minor', major = '', patch = ' -t patch', interactive = 'i' }
  return npx .. ' npm-check-updates -u' .. (flags[type] or '')
end

function M.create_npm_update_executor(type)
  return function()
    local registry = require('custom.utils.terminal_registry')
    registry.get_or_create('npm-update-' .. type, { cmd = M.create_npm_update_command(type) })
  end
end

function M.fms_key_lookup()
  local cwd = vim.fn.getcwd()
  local result = vim.fn.systemlist({ 'fd', 'fallback-no.json', cwd, '--type', 'f', '--max-results', '1', '--exclude', 'node_modules' })

  if #result == 0 then
    vim.notify('No fallback-no.json found in project', vim.log.levels.WARN)
    return
  end

  local fallback_path = result[1]

  local content = vim.fn.readfile(fallback_path)
  local ok, data = pcall(vim.fn.json_decode, table.concat(content, '\n'))
  if not ok or not data then
    vim.notify('Failed to parse fallback-no.json', vim.log.levels.ERROR)
    return
  end

  local items = {}
  for key, value in pairs(data) do
    table.insert(items, {
      text = tostring(value),
      fms_key = key,
      fms_value = tostring(value),
    })
  end
  table.sort(items, function(a, b) return a.fms_value < b.fms_value end)

  local snacks = require('snacks')

  snacks.picker({
    title = 'FMS Text Lookup',
    items = items,
    format = function(item)
      return {
        { item.fms_value, 'String' },
        { ' ', 'Comment' },
        { item.fms_key, 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      local key = item.fms_key
      local rg_output = vim.fn.systemlist({
        'rg', '--no-heading', '--line-number', '--column',
        '--fixed-strings',
        '--type=ts', '--type=js',
        '--glob=!src/fms-fallbacks/**',
        '--glob=!node_modules/**',
        '--glob=!**/fmsTypes.ts',
        '--glob=!**/FmsType.ts',
        '--glob=!**/FmsTypes.ts',
        key, cwd,
      })

      if #rg_output == 0 then
        vim.notify('No usages found for: ' .. key, vim.log.levels.INFO)
        return
      end

      local usage_items = {}
      for _, line in ipairs(rg_output) do
        local file, lnum, col, text = line:match('^(.+):(%d+):(%d+):(.*)$')
        if file then
          local rel_file = vim.fn.fnamemodify(file, ':.')
          table.insert(usage_items, {
            text = rel_file .. ':' .. lnum .. ' ' .. vim.trim(text),
            file = file,
            pos = { tonumber(lnum), tonumber(col) - 1 },
            line = tonumber(lnum),
            col = tonumber(col),
          })
        end
      end

      if #usage_items == 0 then
        vim.notify('No usages found for: ' .. key, vim.log.levels.INFO)
        return
      end

      snacks.picker({
        title = 'Usages of: ' .. key,
        items = usage_items,
        preview = 'file',
        format = function(usage)
          local rel = vim.fn.fnamemodify(usage.file, ':.')
          local icon, hl = snacks.util.icon(rel, 'file')
          return {
            { icon, hl },
            { ' ' },
            { rel, 'Directory' },
            { ':' .. usage.line, 'LineNr' },
            { ' ' },
            { vim.trim(usage.text:match(':.*$') or usage.text), 'Normal' },
          }
        end,
        actions = {
          copy_opencode_link = function(inner_picker, usage_item)
            if not usage_item then return end
            local rel = vim.fn.fnamemodify(usage_item.file, ':.')
            local link = ('@%s:%d'):format(rel, usage_item.line)
            vim.fn.setreg('+', link)
            inner_picker:close()
            vim.notify('Copied: ' .. link, vim.log.levels.INFO)
          end,
        },
        win = {
          input = {
            keys = {
              ['<C-y>'] = { 'copy_opencode_link', desc = 'Copy OpenCode link', mode = { 'n', 'i' } },
            },
          },
        },
        confirm = function(inner_picker, usage)
          inner_picker:close()
          vim.cmd('edit ' .. vim.fn.fnameescape(usage.file))
          vim.api.nvim_win_set_cursor(0, { usage.line, (usage.col or 1) - 1 })
        end,
      })
    end,
  })
end

return M
