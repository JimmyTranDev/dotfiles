local language_utils = require('custom.utils.language')
local ui_utils = require('custom.utils.ui')
local async_utils = require('custom.utils.async')
local validation = require('custom.utils.validation')
local registry = require('custom.utils.terminal_registry')
local usage_cache = require('custom.utils.usage_cache')

local M = {}

local function get_pm()
  local pm = language_utils.get_javascript_package_manager()
  if not pm or pm == '' then
    vim.notify('No JavaScript package manager found', vim.log.levels.ERROR)
    return nil
  end
  return pm
end

-- Parse the target Java major version from pom.xml text. Tries the common
-- version-carrying tags in priority order and normalizes legacy `1.8` -> `8`.
-- Pure (text in, string|nil out) so it is unit-tested headlessly.
---@param pom_xml string
---@return string|nil
function M.parse_pom_java_version(pom_xml)
  local tags = { 'java%.version', 'maven%.compiler%.release', 'maven%.compiler%.target', 'release', 'target' }
  for _, tag in ipairs(tags) do
    local value = pom_xml:match('<' .. tag .. '>%s*([^<]-)%s*</' .. tag .. '>')
    if value and value ~= '' then
      if value:match('^%${') then return nil end
      local legacy = value:match('^1%.(%d+)$')
      if legacy then return legacy end
      local major = value:match('^(%d+)')
      if major then return major end
    end
  end
  return nil
end

-- True when the pom.xml text declares the Spring Boot Maven plugin, i.e. the
-- module is a runnable Spring Boot application.
---@param pom_xml string
---@return boolean
function M.pom_declares_spring_boot(pom_xml) return pom_xml:find('spring-boot-maven-plugin', 1, true) ~= nil end

-- Resolve a major Java version ("21") to an installed SDKMAN JDK home, preferring
-- Temurin (`-tem`) builds and the newest patch. `candidates` is the list of dir
-- names under ~/.sdkman/candidates/java; `opts.home` injects HOME for tests.
---@param version string
---@param candidates string[]
---@param opts? { home?: string }
---@return string|nil
function M.resolve_sdkman_java_home(version, candidates, opts)
  opts = opts or {}
  local home = opts.home or vim.env.HOME

  local function parts(name)
    local nums = {}
    for num in name:gmatch('%d+') do
      nums[#nums + 1] = tonumber(num)
    end
    return nums
  end

  local function newer(a, b)
    local ka, kb = parts(a), parts(b)
    for i = 1, math.max(#ka, #kb) do
      local va, vb = ka[i] or 0, kb[i] or 0
      if va ~= vb then return va > vb end
    end
    return false
  end

  local matches = {}
  for _, name in ipairs(candidates) do
    if name == version or name:match('^' .. version .. '[%.%-]') then matches[#matches + 1] = name end
  end
  if #matches == 0 then return nil end

  table.sort(matches, function(a, b)
    local a_tem = a:find('tem', 1, true) ~= nil
    local b_tem = b:find('tem', 1, true) ~= nil
    if a_tem ~= b_tem then return a_tem end
    return newer(a, b)
  end)

  return home .. '/.sdkman/candidates/java/' .. matches[1]
end

-- Assemble the `spring-boot:run` command. Pure string builder so the exact
-- output is asserted in tests.
---@param opts { module?: string, profile?: string, java_home?: string }
---@return string
function M.build_spring_boot_run_command(opts)
  opts = opts or {}
  local profile = opts.profile or 'local'
  local prefix = opts.java_home and ('JAVA_HOME="' .. opts.java_home .. '" ') or ''
  local pl = opts.module and (' -pl ' .. opts.module) or ''
  return prefix .. 'mvn' .. pl .. ' spring-boot:run -Dspring-boot.run.profiles=' .. profile
end

-- <leader>tvs: run a Spring Boot app from cwd via `spring-boot:run` with the
-- `local` profile. Auto-selects the runnable module (the submodule declaring the
-- Spring Boot Maven plugin) and pins JAVA_HOME to the SDKMAN JDK matching the
-- project's declared Java version, falling back to the default JDK when it can't
-- be resolved.
function M.run_spring_boot()
  local cwd = vim.fn.getcwd()

  if vim.fn.filereadable(cwd .. '/pom.xml') ~= 1 then
    vim.notify('No pom.xml found in cwd', vim.log.levels.ERROR)
    return
  end

  local function read_pom(path) return table.concat(vim.fn.readfile(path), '\n') end

  local java_home
  local version = M.parse_pom_java_version(read_pom(cwd .. '/pom.xml'))
  if version then
    local java_dir = (vim.env.HOME or '') .. '/.sdkman/candidates/java'
    if vim.fn.isdirectory(java_dir) == 1 then java_home = M.resolve_sdkman_java_home(version, vim.fn.readdir(java_dir)) end
  end

  local function run_with_module(module)
    local cmd = M.build_spring_boot_run_command({ module = module, java_home = java_home })
    local label = module or vim.fn.fnamemodify(cwd, ':t')
    ui_utils.exec_in_terminal(cmd, 'Spring Boot: ' .. label, { name = 'spring-boot' })
  end

  local subdirs = vim.fn.readdir(
    cwd,
    function(name) return vim.fn.isdirectory(cwd .. '/' .. name) == 1 and vim.fn.filereadable(cwd .. '/' .. name .. '/pom.xml') == 1 end
  )
  local modules = {}
  for _, name in ipairs(subdirs) do
    if M.pom_declares_spring_boot(read_pom(cwd .. '/' .. name .. '/pom.xml')) then modules[#modules + 1] = name end
  end

  if #modules == 0 then
    run_with_module(nil)
  elseif #modules == 1 then
    run_with_module(modules[1])
  else
    ui_utils.safe_select(modules, { prompt = 'Select Spring Boot module:' }, run_with_module)
  end
end

-- Maven builds skip the git-commit-id plugin: slow and irrelevant for local
-- compile/test/coverage runs. Shared shell fragments keep the coverage
-- commands DRY.
local MVN_SKIP = '-Dmaven.gitcommitid.skip=true'
local MVN_COVERAGE_REPORT = 'mvn clean test jacoco:report ' .. MVN_SKIP
local GIT_CHANGED_JAVA = 'git diff --name-only HEAD~1 -- "*.java"'
local JACOCO_OPEN = 'for d in */target/site/jacoco/index.html; do [ -f "$d" ] && open "$d"; done'

-- Factory: return a fn that toggles (or spawns) a named registry terminal
-- running a fixed command. Keeps one-shot Maven/DB keymaps to a single line
-- instead of a repeated inline closure.
---@param name string
---@param cmd string
---@return function
function M.create_registry_runner(name, cmd)
  return function() registry.get_or_create(name, { cmd = cmd }) end
end

-- <leader>tv* Maven runners.
M.run_maven_package = M.create_registry_runner('mvn-package', 'mvn package')
M.run_maven_test = M.create_registry_runner('mvn-test', 'mvn clean test ' .. MVN_SKIP)
M.run_maven_compile = M.create_registry_runner('mvn-compile', 'mvn compile ' .. MVN_SKIP)

-- <leader>tvf: run only the current Java test file.
function M.run_maven_test_file()
  if vim.bo.filetype ~= 'java' then
    vim.notify('Not a Java file', vim.log.levels.WARN)
    return
  end
  local filename = vim.fn.expand('%:t:r')
  registry.get_or_create('mvn-test-' .. filename, { cmd = ('mvn -Dtest="%s" test %s'):format(filename, MVN_SKIP) })
end

-- <leader>tvc: full clean test + JaCoCo HTML report, opened per module.
function M.run_maven_coverage()
  registry.get_or_create('mvn-coverage', {
    cmd = table.concat({ MVN_COVERAGE_REPORT, JACOCO_OPEN, 'echo "Coverage reports opened"' }, ' && '),
  })
end

-- <leader>tvn: JaCoCo coverage for only the test classes changed since HEAD~1,
-- scoped to the modules that own them.
function M.run_maven_coverage_changed()
  local changed_classes = GIT_CHANGED_JAVA
    .. ' | grep "src/test/.*Test\\.java$"'
    .. ' | sed "s|.*/src/test/java/||; s|\\.java$||; s|/|.|g"'
    .. ' | paste -sd "," -'
  local changed_modules = GIT_CHANGED_JAVA .. ' | grep "src/test/" | sed "s|/src/.*||" | sort -u | paste -sd "," -'
  local cmd = table.concat({
    'CHANGED_CLASSES=$(' .. changed_classes .. ')',
    'if [ -z "$CHANGED_CLASSES" ]; then echo "No changed test classes found"; exit 0; fi',
    'MODULES=$(' .. changed_modules .. ')',
    'echo "Running tests: $CHANGED_CLASSES in modules: $MODULES"',
    'mvn test jacoco:report ' .. MVN_SKIP .. ' -pl "$MODULES" -Dtest="$CHANGED_CLASSES"',
    JACOCO_OPEN,
    'echo "Coverage reports opened for changed tests"',
  }, ' && ')
  registry.get_or_create('mvn-coverage-changed', { cmd = cmd })
end

-- <leader>tvN: diff-cover report of new code vs develop from the JaCoCo XML.
function M.run_maven_diff_coverage()
  local cmd = table.concat({
    MVN_COVERAGE_REPORT,
    'JACOCO_XML=$(find . -path "*/target/site/jacoco/jacoco.xml" -print -quit)',
    'if [ -z "$JACOCO_XML" ]; then echo "No JaCoCo XML report found"; exit 1; fi',
    'diff-cover "$JACOCO_XML" --compare-branch=develop --html-report target/diff-cover.html',
    'open target/diff-cover.html',
    'echo "Diff coverage report opened"',
  }, ' && ')
  registry.get_or_create('mvn-diff-cover', { cmd = cmd })
end

-- <leader>td* Database runners.
M.start_postgres = M.create_registry_runner('postgresql', 'brew services restart postgresql@15')
M.reset_postgres_db = M.create_registry_runner('reset-db', '~/Programming/JimmyTranDev/secrets/reset-db.sh')

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
      if pm then registry.restart('npm-' .. script, { cmd = pm .. ' ' .. script }) end
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
      ui_utils.safe_select(targets, { prompt = 'Make target:' }, function(target) registry.restart('make-' .. target, { cmd = 'make ' .. target }) end)
      return
    end
  end

  vim.notify('No package.json or Makefile found', vim.log.levels.WARN)
end

-- Build the snacks.picker opts for the multi-script runner. Kept pure (no
-- snacks/require/UI side effects) so it can be unit-tested headlessly.
--
-- Snacks multi-select is the DEFAULT (Tab toggles items); the selected set is
-- read in confirm via picker:selected. The `multi` opt is a *list of sources*
-- to combine, NOT a boolean toggle — passing `multi = true` makes snacks call
-- ipairs() on a boolean and crash. So we never set it.
--
-- `sort_items` reorders the built items (default: package.json order) so the
-- caller can float recently-run scripts to the top, and `record` is invoked per
-- launched script so usage can be persisted. Both are injected to keep this
-- builder pure (no usage-cache/UI side effects) and unit-testable headlessly.
---@param scripts string[]
---@param pm string
---@param opts? { max_splits?: integer, run?: fun(name: string, spec: table), notify?: fun(msg: string, level: integer), sort_items?: fun(items: table[]): table[], record?: fun(script: string) }
function M.build_multi_script_picker_opts(scripts, pm, opts)
  opts = opts or {}
  local max_splits = opts.max_splits or 6
  local run = opts.run or function(name, spec) registry.get_or_create(name, spec) end
  local notify = opts.notify or function(msg, level) vim.notify(msg, level) end
  local record = opts.record or function(_) end
  local sort_items = opts.sort_items or function(items) return items end

  local items = {}
  for _, script in ipairs(scripts) do
    table.insert(items, { text = script, script = script })
  end
  items = sort_items(items)

  return {
    title = 'Select npm scripts (multi-select with Tab)',
    items = items,
    format = function(item) return { { item.text } } end,
    confirm = function(picker)
      picker:close()
      local selected = picker:selected({ fallback = true })
      if not selected or #selected == 0 then return end

      if #selected > max_splits then notify('Capped to ' .. max_splits .. ' scripts (selected ' .. #selected .. ')', vim.log.levels.WARN) end

      local count = math.min(#selected, max_splits)
      for i = 1, count do
        local script = selected[i].script
        record(script)
        run('npm-run-' .. script, {
          cmd = pm .. ' run ' .. script,
          close_on_exit = false,
        })
      end
    end,
  }
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

    local ok, snacks = pcall(require, 'snacks')
    if not ok then
      vim.notify('Snacks not available', vim.log.levels.ERROR)
      return
    end

    -- Scope recency per project so each repo keeps its own most-recent order.
    local ns = 'npm_scripts:' .. vim.fn.getcwd()
    snacks.picker(M.build_multi_script_picker_opts(scripts, pm, {
      sort_items = function(items)
        return usage_cache.sort_by_recency(ns, items, function(item) return item.script end)
      end,
      record = function(script) usage_cache.record(ns, script) end,
    }))
  end
end

function M.kill_multiple_package_script_terms()
  return function()
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
    local full_cmd = pm .. ' ' .. command
    if should_exit then full_cmd = full_cmd .. ' && exit' end
    registry.get_or_create('npm-' .. command:gsub('%s+', '-'), { cmd = full_cmd, close_on_exit = should_exit })
  end
end

local function find_nearest_package_json()
  local dir = vim.fn.expand('%:p:h')
  if dir == '' then dir = vim.fn.getcwd() end

  while dir and dir ~= '' do
    local package_json = dir .. '/package.json'
    if vim.fn.filereadable(package_json) == 1 then return dir, package_json end

    local parent = vim.fn.fnamemodify(dir, ':h')
    if parent == dir then break end
    dir = parent
  end

  return nil, nil
end

local TEST_RUNNER_CONFIGS = {
  vitest = {
    'vitest.config.ts',
    'vitest.config.js',
    'vitest.config.mjs',
    'vitest.config.mts',
    'vitest.config.cjs',
    'vitest.workspace.ts',
    'vitest.workspace.js',
  },
  jest = { 'jest.config.ts', 'jest.config.js', 'jest.config.mjs', 'jest.config.cjs', 'jest.config.json' },
}

local function detect_js_test_runner(dir, package_json)
  for runner, configs in pairs(TEST_RUNNER_CONFIGS) do
    for _, config in ipairs(configs) do
      if vim.fn.filereadable(dir .. '/' .. config) == 1 then return runner end
    end
  end

  local content = vim.fn.readfile(package_json)
  local ok, data = pcall(vim.json.decode, table.concat(content, '\n'))
  if ok and data then
    local deps = vim.tbl_extend('force', data.dependencies or {}, data.devDependencies or {})
    if deps.vitest then return 'vitest' end
    if deps.jest then return 'jest' end
  end

  return nil
end

local PM_EXEC = {
  npm = 'npx',
  pnpm = 'pnpm exec',
  yarn = 'yarn',
  bun = 'bunx',
}

local RUNNER_COVERAGE_CMD = {
  vitest = 'vitest run --coverage',
  jest = 'jest --coverage',
}

function M.run_test_coverage()
  local pm = get_pm()
  if not pm then return end

  local dir, package_json = find_nearest_package_json()
  if not dir then
    vim.notify('No package.json found', vim.log.levels.WARN)
    return
  end

  local runner = detect_js_test_runner(dir, package_json)
  if not runner then
    vim.notify('No supported test runner (vitest/jest) found', vim.log.levels.WARN)
    return
  end

  local exec = PM_EXEC[pm] or 'npx'
  local label = vim.fn.fnamemodify(dir, ':t')
  local cmd = ('cd %s && %s %s'):format(vim.fn.shellescape(dir), exec, RUNNER_COVERAGE_CMD[runner])
  ui_utils.exec_in_terminal(cmd, ('Test coverage (%s): %s'):format(runner, label), { name = 'test-coverage' })
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

    local ok, result = pcall(vim.json.decode, output)
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
        table.insert(
          items,
          {
            file = file,
            line = export.line or 1,
            pos = { export.line or 1, 0 },
            text = ('%s:%d - export: %s'):format(file, export.line or 1, export.name or '?'),
          }
        )
      end
      for _, typ in ipairs(issue.types or {}) do
        table.insert(
          items,
          { file = file, line = typ.line or 1, pos = { typ.line or 1, 0 }, text = ('%s:%d - type: %s'):format(file, typ.line or 1, typ.name or '?') }
        )
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
  async_utils.run_cmd({ pm, 'dlx', 'knip', '--fix' }, function() vim.notify('Knip fix completed for ' .. dir, vim.log.levels.INFO) end)
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

    ui_utils.safe_select(targets, { prompt = 'Make target:' }, function(target) registry.get_or_create('make-' .. target, { cmd = 'make ' .. target }) end)
  end
end

function M.create_npm_update_command(type)
  local npx = language_utils.get_npx_equivalent()
  local flags = { minor = ' -t minor', major = '', patch = ' -t patch', interactive = 'i' }
  return npx .. ' npm-check-updates -u' .. (flags[type] or '')
end

function M.create_npm_update_executor(type)
  return function() registry.get_or_create('npm-update-' .. type, { cmd = M.create_npm_update_command(type) }) end
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
  local ok, data = pcall(vim.json.decode, table.concat(content, '\n'))
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
        'rg',
        '--no-heading',
        '--line-number',
        '--column',
        '--fixed-strings',
        '--type=ts',
        '--type=js',
        '--glob=!src/fms-fallbacks/**',
        '--glob=!node_modules/**',
        '--glob=!**/fmsTypes.ts',
        '--glob=!**/FmsType.ts',
        '--glob=!**/FmsTypes.ts',
        key,
        cwd,
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
