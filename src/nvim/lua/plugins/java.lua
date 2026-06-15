--- Register buffer-local Java keymaps, grouped by concern under <leader>J.
--- Buffer-local so the bindings only exist inside Java buffers.
---@param bufnr integer
local function set_java_keymaps(bufnr)
  local java = require('custom.actions.java')

  local function map(mode, lhs, rhs, desc) vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, silent = true, desc = desc }) end

  -- Runner ------------------------------------------------------------
  map('n', '<leader>Jrr', java.run_main, '󰜎 Run Main')
  map('n', '<leader>Jrs', java.stop_main, '󰓛 Stop Main')
  map('n', '<leader>Jrl', java.toggle_logs, '󰦪 Toggle Runner Logs')

  -- Test --------------------------------------------------------------
  map('n', '<leader>Jtc', java.test_class, '󰙨 Test Current Class')
  map('n', '<leader>Jtm', java.test_method, '󰙨 Test Current Method')
  map('n', '<leader>Jta', java.test_all, '󰙨 Test All')
  map('n', '<leader>Jtv', java.view_report, '󰋽 View Last Test Report')

  -- Debug -------------------------------------------------------------
  map('n', '<leader>Jdc', java.debug_class, '󰃤 Debug Current Class')
  map('n', '<leader>Jdm', java.debug_method, '󰃤 Debug Current Method')
  map('n', '<leader>Jda', java.debug_all, '󰃤 Debug All')
  map('n', '<leader>JdC', java.config_dap, '󰒓 Configure DAP')

  -- Extract / Refactor (work on cursor or visual selection) -----------
  map({ 'n', 'v' }, '<leader>Jev', java.extract_variable, '󰂽 Extract Variable')
  map({ 'n', 'v' }, '<leader>JeV', java.extract_variable_all, '󰂽 Extract Variable (All Occurrences)')
  map({ 'n', 'v' }, '<leader>Jec', java.extract_constant, '󰂽 Extract Constant')
  map({ 'n', 'v' }, '<leader>Jem', java.extract_method, '󰂽 Extract Method')
  map({ 'n', 'v' }, '<leader>Jef', java.extract_field, '󰂽 Extract Field')

  -- Generate / Source actions -----------------------------------------
  map('n', '<leader>Jgo', java.organize_imports, '󰒺 Organize Imports')
  map('n', '<leader>Jga', java.generate_accessors, '󰖷 Generate Getters/Setters')
  map('n', '<leader>Jgc', java.generate_constructor, '󰖷 Generate Constructor')
  map('n', '<leader>Jgt', java.generate_to_string, '󰖷 Generate toString()')
  map('n', '<leader>Jge', java.generate_equals_hashcode, '󰖷 Generate equals/hashCode')
  map('n', '<leader>Jgm', java.override_methods, '󰖷 Override/Implement Methods')

  -- Build -------------------------------------------------------------
  map('n', '<leader>Jbb', java.build_workspace, '󰜫 Build Workspace')
  map('n', '<leader>Jbc', java.clean_workspace, '󰃢 Clean Workspace')

  -- Settings ----------------------------------------------------------
  map('n', '<leader>Jsr', java.change_runtime, '󰜉 Change JDK Runtime')
  map('n', '<leader>Jsp', java.profile_ui, '󰒓 Profiles UI')
end

return {
  ft = { 'java' },
  'nvim-java/nvim-java',
  config = function()
    require('java').setup()

    local group = vim.api.nvim_create_augroup('java_keymaps', { clear = true })
    vim.api.nvim_create_autocmd('FileType', {
      group = group,
      pattern = 'java',
      callback = function(args) set_java_keymaps(args.buf) end,
    })

    -- The FileType event for the buffer that lazy-loaded this plugin has
    -- already fired, so apply the keymaps to it directly.
    if vim.bo.filetype == 'java' then set_java_keymaps(vim.api.nvim_get_current_buf()) end

    local formatter_path = vim.fn.stdpath('config') .. '/etc/intellij-java-style.xml'

    vim.lsp.config('jdtls', {
      settings = {
        java = {
          format = {
            enabled = true,
            settings = {
              url = formatter_path,
              profile = 'IntelliJStyle',
            },
          },
          compile = {
            nullAnalysis = {
              mode = 'automatic',
            },
          },
          cleanup = {
            actionsOnSave = {
              'addOverride',
              'addDeprecated',
              'qualifyMembers',
              'qualifyStaticMembers',
              'organizeImports',
            },
          },
          diagnostics = {
            unusedImports = 'warning',
            unusedVariables = 'warning',
            unusedParameters = 'warning',
          },
          saveActions = {
            organizeImports = true,
          },
        },
      },
    })

    vim.lsp.enable('jdtls')
  end,
}
