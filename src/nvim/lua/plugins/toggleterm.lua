local language_actions = require('custom.actions.language')
local pnpm_actions = require('custom.actions.pnpm')
local toggle_term_actions = require('custom.actions.toggleterm')

return {
  'akinsho/toggleterm.nvim',
  keys = {

    { mode = 'n', '<leader>tf', toggle_term_actions.open_terminal_picker, desc = '󰆍 Terminal Picker', silent = true },
    { mode = 'n', '<leader>tt', toggle_term_actions.create_blank_terminal, desc = '󰆍 New Terminal', silent = true },

    { mode = 't', '<C-h>', [[<Cmd>wincmd h<CR>]], desc = '󰖲 Terminal left window', silent = true },
    { mode = 't', '<C-j>', [[<Cmd>wincmd j<CR>]], desc = '󰖲 Terminal down window', silent = true },
    { mode = 't', '<C-k>', [[<Cmd>wincmd k<CR>]], desc = '󰖲 Terminal up window', silent = true },
    { mode = 't', '<C-l>', [[<Cmd>wincmd l<CR>]], desc = '󰖲 Terminal right window', silent = true },
    {
      mode = 't',
      '<Esc>',
      function()
        local keys = vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true)
        vim.api.nvim_feedkeys(keys, 'n', false)
      end,
      desc = '󰅁 Terminal escape to normal mode',
      silent = true,
    },

    { mode = 'n', '<leader>tnum', language_actions.create_npm_update_executor('minor'), silent = true, desc = '󰎙 Npm Update Minor' },
    { mode = 'n', '<leader>tnun', language_actions.create_npm_update_executor('major'), silent = true, desc = '󰎙 Npm Update Major' },
    { mode = 'n', '<leader>tnup', language_actions.create_npm_update_executor('patch'), silent = true, desc = '󰎙 Npm Update Patch' },
    { mode = 'n', '<leader>tnui', language_actions.create_npm_update_executor('interactive'), silent = true, desc = '󰎙 Npm Update Interactive' },

    { mode = 'n', '<leader>tni', language_actions.create_package_command_runner('install', true), silent = true, desc = '󰎙 Npm Install' },

    { mode = 'n', '<leader>tx', toggle_term_actions.kill_all_terminals, silent = true, desc = '󰅗 Kill All Terminals' },

    { mode = 'n', '<leader>tnm', language_actions.run_multiple_package_scripts(), silent = true, desc = '󰎙 Multi-select Npm Scripts' },
    { mode = 'n', '<leader>tnM', language_actions.kill_multiple_package_script_terms(), silent = true, desc = '󰎙 Kill Npm Script Terminals' },

    { mode = 'n', '<leader>tnj', function() language_actions.run_package_script() end, silent = true, desc = '󰎙 Run Npm/Make Script' },

    {
      mode = 'n',
      '<leader>tnf',
      language_actions.create_package_command_runner('fms:types', true),
      silent = true,
      desc = '󰎙 Npm FMS Types and Gen',
    },
    {
      mode = 'n',
      '<leader>tna',
      function()
        language_actions.create_package_command_runner('build', true)()
        language_actions.create_package_command_runner('lint:fix', true)()
        language_actions.create_package_command_runner('test', true)()
      end,
      silent = true,
      desc = '󰎙 Npm All (build, lint, test)',
    },

    { mode = 'n', '<leader>tny', pnpm_actions.pnpm_link, silent = true, desc = '󰎙 pnpm link package' },
    { mode = 'n', '<leader>tnY', pnpm_actions.pnpm_unlink, silent = true, desc = '󰎙 pnpm unlink package' },

    { mode = 'n', '<leader>tmj', language_actions.create_make_command_runner(), desc = '󰣖 Run Makefile Target', silent = true },
    {
      mode = 'n',
      '<leader>tms',
      function()
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('make-start', { cmd = 'make start' })
      end,
      desc = '󰣖 Make Start',
      silent = true,
    },

    { mode = 'n', '<leader>tvs', language_actions.run_spring_boot, desc = '󰫙 Start Spring Boot (local)', silent = true },
    { mode = 'n', '<leader>tvp', language_actions.run_maven_package, desc = '󰫙 Maven Package', silent = true },
    { mode = 'n', '<leader>tvt', language_actions.run_maven_test, desc = '󰫙 Maven Test', silent = true },
    { mode = 'n', '<leader>tvf', language_actions.run_maven_test_file, desc = '󰫙 Maven Test Current File', silent = true },
    { mode = 'n', '<leader>tvc', language_actions.run_maven_coverage, desc = '󰫙 Maven Test Coverage', silent = true },
    { mode = 'n', '<leader>tvn', language_actions.run_maven_coverage_changed, desc = '󰫙 Maven Test Coverage (Changed Tests)', silent = true },
    { mode = 'n', '<leader>tvN', language_actions.run_maven_diff_coverage, desc = '󰫙 Maven Test Coverage (New Code via diff-cover)', silent = true },
    { mode = 'n', '<leader>tvb', language_actions.run_maven_compile, desc = '󰫙 Maven Compile', silent = true },

    { mode = 'n', '<leader>tds', language_actions.start_postgres, desc = '󰆼 Start PostgreSQL', silent = true },
    { mode = 'n', '<leader>tdr', language_actions.reset_postgres_db, desc = '󰆼 Reset PostgreSQL DB', silent = true },
  },
  config = function()
    require('toggleterm').setup({
      size = 15,
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 1,
      start_in_insert = true,
      insert_mappings = false,
      terminal_mappings = true,
      direction = 'horizontal',
    })
  end,
}
