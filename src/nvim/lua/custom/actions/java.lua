-- Java actions backed by nvim-java (jdtls).
-- Organised by concern: runner, test, debug, refactor, source generation,
-- build, and settings. Each section maps to a which-key subgroup under
-- <leader>J (see plugins/java.lua and plugins/which-key.lua).

local M = {}

--- Wrap an :Java* ex-command so failures surface a readable notification
--- instead of a raw stack trace (e.g. when jdtls has not attached yet).
---@param name string
---@return function
local function run_ex(name)
  return function()
    local ok, err = pcall(vim.cmd, name)
    if not ok then vim.notify('Java: failed to run ' .. name .. '\n' .. tostring(err), vim.log.levels.ERROR) end
  end
end

--- Apply a single jdtls source/refactor code action by kind, skipping the
--- code-action menu when exactly one action matches.
---@param kind string
---@return function
local function source_action(kind)
  return function()
    if vim.bo.filetype ~= 'java' then
      vim.notify('Not a Java file', vim.log.levels.WARN)
      return
    end
    vim.lsp.buf.code_action({
      apply = true,
      context = { only = { kind } },
    })
  end
end

--- Call an nvim-java refactor API function directly so the current visual
--- selection is respected (the ex-commands rely on range plumbing).
---@param fn_name string
---@return function
local function refactor(fn_name)
  return function()
    local ok, api = pcall(require, 'java-refactor.api.refactor')
    if not ok then
      vim.notify('Java refactor API unavailable (is jdtls attached?)', vim.log.levels.ERROR)
      return
    end
    api[fn_name]()
  end
end

----------------------------------------------------------------------
--                              Runner                              --
----------------------------------------------------------------------
M.run_main = run_ex('JavaRunnerRunMain')
M.stop_main = run_ex('JavaRunnerStopMain')
M.toggle_logs = run_ex('JavaRunnerToggleLogs')

----------------------------------------------------------------------
--                               Test                               --
----------------------------------------------------------------------
M.test_class = run_ex('JavaTestRunCurrentClass')
M.test_method = run_ex('JavaTestRunCurrentMethod')
M.test_all = run_ex('JavaTestRunAllTests')
M.view_report = run_ex('JavaTestViewLastReport')

----------------------------------------------------------------------
--                              Debug                               --
----------------------------------------------------------------------
M.debug_class = run_ex('JavaTestDebugCurrentClass')
M.debug_method = run_ex('JavaTestDebugCurrentMethod')
M.debug_all = run_ex('JavaTestDebugAllTests')
M.config_dap = run_ex('JavaDapConfig')

----------------------------------------------------------------------
--                             Refactor                             --
----------------------------------------------------------------------
M.extract_variable = refactor('extract_variable')
M.extract_variable_all = refactor('extract_variable_all_occurrence')
M.extract_constant = refactor('extract_constant')
M.extract_method = refactor('extract_method')
M.extract_field = refactor('extract_field')

----------------------------------------------------------------------
--                        Source generation                         --
----------------------------------------------------------------------
M.organize_imports = source_action('source.organizeImports')
M.generate_accessors = source_action('source.generateAccessors')
M.generate_constructor = source_action('source.generateConstructors')
M.generate_to_string = source_action('source.generate.toString')
M.generate_equals_hashcode = source_action('source.generate.hashCodeEquals')
M.override_methods = source_action('source.overrideMethods')

----------------------------------------------------------------------
--                              Build                               --
----------------------------------------------------------------------
M.build_workspace = run_ex('JavaBuildBuildWorkspace')
M.clean_workspace = run_ex('JavaBuildCleanWorkspace')

----------------------------------------------------------------------
--                            Settings                              --
----------------------------------------------------------------------
M.change_runtime = run_ex('JavaSettingsChangeRuntime')
M.profile_ui = run_ex('JavaProfile')

return M
