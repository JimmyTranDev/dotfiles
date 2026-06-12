local language_actions = require('custom.actions.language')
local pnpm_actions = require('custom.actions.pnpm')
local toggle_term_actions = require('custom.actions.toggleterm')

return {
  'akinsho/nvim-toggleterm.lua',
  keys = {

    {
      mode = 'n',
      '<leader>t1',
      function()
        local id = toggle_term_actions.get_next_free_terminal(1)
        vim.cmd(id .. 'ToggleTerm')
      end,
      desc = '󰆍 Toggle Terminal (next free from 1)',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>t2',
      function()
        local id = toggle_term_actions.get_next_free_terminal(2)
        vim.cmd(id .. 'ToggleTerm')
      end,
      desc = '󰆍 Toggle Terminal (next free from 2)',
      silent = true,
    },

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

    { mode = 'n', '<leader>tnum', language_actions.create_npm_update_executor(7, 'minor'), silent = true, desc = '󰎙 Npm Update Minor' },
    { mode = 'n', '<leader>tnun', language_actions.create_npm_update_executor(7, 'major'), silent = true, desc = '󰎙 Npm Update Major' },
    { mode = 'n', '<leader>tnup', language_actions.create_npm_update_executor(7, 'patch'), silent = true, desc = '󰎙 Npm Update Patch' },
    { mode = 'n', '<leader>tnui', language_actions.create_npm_update_executor(7, 'interactive'), silent = true, desc = '󰎙 Npm Update Interactive' },

    { mode = 'n', '<leader>tni', language_actions.create_package_command_runner(8, 'install', true), silent = true, desc = '󰎙 Npm Install' },

    { mode = 'n', '<leader>tx', toggle_term_actions.kill_all_toggle_term, silent = true, desc = '󰅗 Kill All Terminals' },

    { mode = 'n', '<leader>tnm', language_actions.run_multiple_package_scripts(10), silent = true, desc = '󰎙 Multi-select Npm Scripts' },
    { mode = 'n', '<leader>tnM', language_actions.kill_multiple_package_script_terms(10, 6), silent = true, desc = '󰎙 Kill Multi-select Scripts' },

    { mode = 'n', '<leader>tnj', function() language_actions.run_package_script(1) end, silent = true, desc = '󰎙 Npm Script 1' },
    { mode = 'n', '<leader>tnJ', toggle_term_actions.create_kill_toggle_term(1), silent = true, desc = '󰎙 Npm Script 1 Exit' },
    { mode = 'n', '<leader>tnk', function() language_actions.run_package_script(2) end, silent = true, desc = '󰎙 Npm Script 2' },
    { mode = 'n', '<leader>tnK', toggle_term_actions.create_kill_toggle_term(2), silent = true, desc = '󰎙 Npm Script 2 Exit' },
    { mode = 'n', '<leader>tnl', function() language_actions.run_package_script(3) end, silent = true, desc = '󰎙 Npm Script 3' },
    { mode = 'n', '<leader>tnL', toggle_term_actions.create_kill_toggle_term(3), silent = true, desc = '󰎙 Npm Script 3 Exit' },
    { mode = 'n', '<leader>tn;', function() language_actions.run_package_script(4) end, silent = true, desc = '󰎙 Npm Script 4' },
    { mode = 'n', '<leader>tn:', toggle_term_actions.create_kill_toggle_term(4), silent = true, desc = '󰎙 Npm Script 4 Exit' },

    {
      mode = 'n',
      '<leader>tnf',
      function() language_actions.create_package_command_runner(9, 'fms:types', true)() end,
      silent = true,
      desc = '󰎙 Npm FMS Types and Gen',
    },
    {
      mode = 'n',
      '<leader>tna',
      function()
        language_actions.create_package_command_runner(5, 'build && exit')()
        language_actions.create_package_command_runner(6, 'lint:fix && exit')()
        language_actions.create_package_command_runner(7, 'test && exit')()
      end,
      silent = true,
      desc = '󰎙 Npm All (build, lint, test)',
    },
    {
      mode = 'n',
      '<leader>tnA',
      function()
        for i = 6, 8 do
          toggle_term_actions.create_kill_toggle_term(i)()
        end
      end,
      silent = true,
      desc = '󰎙 Npm Kill All (build, lint, test)',
    },

    { mode = 'n', '<leader>tny', pnpm_actions.pnpm_link, silent = true, desc = '󰎙 pnpm link package' },
    { mode = 'n', '<leader>tnY', pnpm_actions.pnpm_unlink, silent = true, desc = '󰎙 pnpm unlink package' },

    { mode = 'n', '<leader>tmj', language_actions.create_make_command_runner(1), desc = '󰣖 Run Makefile Target', silent = true },
    { mode = 'n', '<leader>tmJ', toggle_term_actions.create_kill_toggle_term(1), desc = '󰣖 Makefile Exit', silent = true },
    { mode = 'n', '<leader>tmk', language_actions.create_make_command_runner(2), desc = '󰣖 Run Makefile Target', silent = true },
    { mode = 'n', '<leader>tmK', toggle_term_actions.create_kill_toggle_term(2), desc = '󰣖 Makefile Exit', silent = true },
    { mode = 'n', '<leader>tmm', language_actions.create_make_command_runner(3), desc = '󰣖 Run Makefile Target', silent = true },
    { mode = 'n', '<leader>tmM', toggle_term_actions.create_kill_toggle_term(3), desc = '󰣖 Makefile Exit', silent = true },
    { mode = 'n', '<leader>tms', ':1TermExec cmd="make start"<CR>', desc = '󰣖 Make Start', silent = true },

    { mode = 'n', '<leader>tvs', language_actions.run_project_jar, desc = '󰫙 Start Project (Maven/Node)', silent = true },
    { mode = 'n', '<leader>tvp', ':3TermExec cmd="mvn package"<CR>', desc = '󰫙 Maven Package', silent = true },
    { mode = 'n', '<leader>tvt', ':3TermExec cmd="mvn clean test -Dmaven.gitcommitid.skip=true"<CR>', desc = '󰫙 Maven Test', silent = true },
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
        require('toggleterm').exec(cmd, 3)
      end,
      desc = '󰫙 Maven Test Current File',
      silent = true,
    },
    {
      mode = 'n',
      '<leader>tvc',
      function()
        require('toggleterm').exec(
          'mvn clean test jacoco:report -Dmaven.gitcommitid.skip=true && for d in */target/site/jacoco/index.html; do [ -f "$d" ] && open "$d"; done && echo "Coverage reports opened"',
          3
        )
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
        require('toggleterm').exec(cmd, 3)
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
        require('toggleterm').exec(cmd, 3)
      end,
      desc = '󰫙 Maven Test Coverage (New Code via diff-cover)',
      silent = true,
    },
    { mode = 'n', '<leader>tvb', ':3TermExec cmd="mvn compile -Dmaven.gitcommitid.skip=true"<CR>', desc = '󰫙 Maven Compile', silent = true },

    { mode = 'n', '<leader>tvq', ':3TermExec cmd="brew services restart postgresql@15"<CR>', desc = '󰫙 Start PostgreSQL', silent = true },
    { mode = 'n', '<leader>tvr', ':3TermExec cmd="~/Programming/JimmyTranDev/secrets/reset-db.sh"<CR>', desc = '󰫙 Reset PostgreSQL DB', silent = true },
  },
  config = function()
    require('toggleterm').setup({
      size = 15,
      open_mapping = [[<c-\>]],
      shade_filetypes = {},
      shade_terminals = true,
      shading_factor = 1,
      start_in_insert = true,
      insert_mappings = true,
      terminal_mappings = true,
      direction = 'horizontal',
    })

    vim.keymap.set('n', [[<c-\>]], [[<Cmd>execute v:count1 . "ToggleTerm"<CR>]], { silent = true })
    vim.keymap.set('i', [[<c-\>]], [[<Esc><Cmd>execute v:count1 . "ToggleTerm"<CR>]], { silent = true })

  end,
}
