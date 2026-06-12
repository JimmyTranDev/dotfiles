local language_actions = require('custom.actions.language')
local pnpm_actions = require('custom.actions.pnpm')
local toggle_term_actions = require('custom.actions.toggleterm')

return {
  'akinsho/nvim-toggleterm.lua',
  keys = {

    { mode = 'n', '<leader>tt', toggle_term_actions.open_terminal_picker, desc = '󰆍 Terminal Picker', silent = true },
    { mode = 'n', '<leader>tc', toggle_term_actions.create_blank_terminal, desc = '󰆍 New Terminal', silent = true },

    { mode = 't', '<C-h>', [[<Cmd>wincmd h<CR>]], desc = '󰖲 Terminal left window', silent = true },
    { mode = 't', '<C-j>', [[<Cmd>wincmd j<CR>]], desc = '󰖲 Terminal down window', silent = true },
    { mode = 't', '<C-k>', [[<Cmd>wincmd k<CR>]], desc = '󰖲 Terminal up window', silent = true },
    { mode = 't', '<C-l>', [[<Cmd>wincmd l<CR>]], desc = '󰖲 Terminal right window', silent = true },
    {
      mode = 't',
      '<Esc>',
      function()
        local bufname = vim.api.nvim_buf_get_name(0)
        if bufname:find('opencode') then
          local chan = vim.b.terminal_job_id
          if chan then
            vim.api.nvim_chan_send(chan, '\27')
          end
        else
          local keys = vim.api.nvim_replace_termcodes([[<C-\><C-n>]], true, false, true)
          vim.api.nvim_feedkeys(keys, 'n', false)
        end
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

    { mode = 'n', '<leader>tvs', language_actions.run_project_jar, desc = '󰫙 Start Project (Maven/Node)', silent = true },
    {
      mode = 'n',
      '<leader>tvp',
      function()
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-package', { cmd = 'mvn package' })
      end,
      desc = '󰫙 Maven Package',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvt',
      function()
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-test', { cmd = 'mvn clean test -Dmaven.gitcommitid.skip=true' })
      end,
      desc = '󰫙 Maven Test',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvf',
      function()
        if vim.bo.filetype ~= 'java' then
          vim.notify('Not a Java file', vim.log.levels.WARN)
          return
        end
        local filename = vim.fn.expand('%:t:r')
        local cmd = 'mvn -Dtest="' .. filename .. '" test -Dmaven.gitcommitid.skip=true'
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-test-' .. filename, { cmd = cmd })
      end,
      desc = '󰫙 Maven Test Current File',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvc',
      function()
        local cmd = 'mvn clean test jacoco:report -Dmaven.gitcommitid.skip=true && for d in */target/site/jacoco/index.html; do [ -f "$d" ] && open "$d"; done && echo "Coverage reports opened"'
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-coverage', { cmd = cmd })
      end,
      desc = '󰫙 Maven Test Coverage',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvn',
      function()
        local cmd = table.concat({
          'CHANGED_CLASSES=$(git diff --name-only HEAD~1 -- "*.java"',
          '  | grep "src/test/.*Test\\.java$"',
          '  | sed "s|.*/src/test/java/||; s|\\.java$||; s|/|.|g"',
          '  | paste -sd "," -)',
          'if [ -z "$CHANGED_CLASSES" ]; then echo "No changed test classes found"; exit 0; fi',
          'MODULES=$(git diff --name-only HEAD~1 -- "*.java"',
          '  | grep "src/test/"',
          '  | sed "s|/src/.*||"',
          '  | sort -u',
          '  | paste -sd "," -)',
          'echo "Running tests: $CHANGED_CLASSES in modules: $MODULES"',
          'mvn test jacoco:report -Dmaven.gitcommitid.skip=true -pl "$MODULES" -Dtest="$CHANGED_CLASSES"',
          '&& for d in */target/site/jacoco/index.html; do [ -f "$d" ] && open "$d"; done',
          '&& echo "Coverage reports opened for changed tests"',
        }, ' && ')
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-coverage-changed', { cmd = cmd })
      end,
      desc = '󰫙 Maven Test Coverage (Changed Tests)',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvN',
      function()
        local cmd = table.concat({
          'mvn clean test jacoco:report -Dmaven.gitcommitid.skip=true',
          '&& JACOCO_XML=$(find . -path "*/target/site/jacoco/jacoco.xml" -print -quit)',
          '&& if [ -z "$JACOCO_XML" ]; then echo "No JaCoCo XML report found"; exit 1; fi',
          '&& diff-cover "$JACOCO_XML" --compare-branch=develop --html-report target/diff-cover.html',
          '&& open target/diff-cover.html',
          '&& echo "Diff coverage report opened"',
        }, ' ')
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-diff-cover', { cmd = cmd })
      end,
      desc = '󰫙 Maven Test Coverage (New Code via diff-cover)',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvb',
      function()
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('mvn-compile', { cmd = 'mvn compile -Dmaven.gitcommitid.skip=true' })
      end,
      desc = '󰫙 Maven Compile',
      silent = true,
    },

    {
      mode = 'n',
      '<leader>tvq',
      function()
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('postgresql', { cmd = 'brew services restart postgresql@15' })
      end,
      desc = '󰫙 Start PostgreSQL',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvr',
      function()
        local registry = require('custom.utils.terminal_registry')
        registry.get_or_create('reset-db', { cmd = '~/Programming/JimmyTranDev/secrets/reset-db.sh' })
      end,
      desc = '󰫙 Reset PostgreSQL DB',
      silent = true,
    },
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
