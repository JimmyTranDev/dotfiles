local file_actions = require('custom.actions.files')

return {
  'folke/snacks.nvim',
  lazy = true,
  priority = 1000,
  event = 'UIEnter',
  opts = {
    bigfile = { enabled = true },
    dashboard = {
      enabled = true,
      sections = {
        { section = 'header' },
        {
          icon = ' ',
          title = 'Recent Files',
          section = 'recent_files',
          indent = 2,
          padding = 1,
          cwd = true,
        },
        { icon = ' ', title = 'Keymaps', section = 'keys', indent = 2, padding = 1 },
        { section = 'startup' },
      },
    },
    explorer = { enabled = false },
    indent = {
      enabled = true,
      filter = function(buf)
        local ft = vim.bo[buf].filetype
        return ft ~= 'markdown' and ft ~= 'mdx'
      end,
    },
    input = { enabled = true },
    picker = {
      enabled = true,
      cwd = true,
      layout = {
        layout = {},
      },
      formatters = {
        file = {
          truncate = 60,
        },
      },
      sources = {
        files = {
          exclude = { 'pnpm-lock.yaml', 'yarn.lock', 'package-lock.json', 'bun.lockb', 'bun.lock' },
        },
        grep = {
          exclude = { 'pnpm-lock.yaml', 'yarn.lock', 'package-lock.json', 'bun.lockb', 'bun.lock' },
        },
        explorer = {
          exclude = { 'pnpm-lock.yaml', 'yarn.lock', 'package-lock.json', 'bun.lockb', 'bun.lock' },
        },
      },
      jump = {
        jumplist = true,
        tagstack = false,
        reuse_win = true,
        close = true,
        match = false,
      },
    },
    notifier = { enabled = true },
    quickfile = { enabled = true },
    scope = {
      enabled = true,
      filter = function(buf)
        local ft = vim.bo[buf].filetype
        return ft ~= 'markdown' and ft ~= 'mdx'
      end,
    },
    scroll = { enabled = false },
    statuscolumn = { enabled = false },
    words = { enabled = false },
  },
  keys = {
    -- LazyGit in a snacks float. Hiding the window (<C-g>) keeps the lazygit
    -- process alive so UI state (panel, cursor, scroll, expanded diffs) is
    -- preserved between opens. Pressing `q` quits lazygit and resets state.
    {
      '<leader>m',
      function()
        Snacks.lazygit({
          win = {
            keys = {
              hide_lazygit = { '<C-g>', 'hide', mode = 't' },
            },
          },
        })
      end,
      desc = '󰘻 LazyGit',
    },
    {
      'ga',
      vim.lsp.buf.code_action,
      desc = '󰌵 LSP Code Action',
      mode = { 'n', 'v' },
    },
    {
      'gm',
      vim.diagnostic.open_float,
      desc = '󰒡 LSP Diagnostic',
      mode = { 'n', 'v' },
    },
    {
      'gh',
      vim.lsp.buf.hover,
      desc = '󰋽 LSP Hover',
      mode = { 'n', 'v' },
    },
    {
      'gl',
      vim.lsp.buf.format,
      desc = '󰉼 LSP Format',
      mode = { 'n', 'v' },
    },
    {
      'gd',
      function() Snacks.picker.lsp_definitions() end,
      desc = '󰈮 Goto Definition',
    },
    {
      'gD',
      function() Snacks.picker.lsp_declarations() end,
      desc = '󰈮 Goto Declaration',
    },
    {
      'gz',
      function() Snacks.picker.lsp_references() end,
      nowait = true,
      desc = '󰌹 References',
    },
    {
      'gi',
      function() Snacks.picker.lsp_implementations() end,
      desc = '󰡱 Goto Implementation',
    },
    {
      'gH',
      function() Snacks.picker.lsp_type_definitions() end,
      desc = '󰜁 Goto Type Definition',
    },
    {
      'gn',
      function() vim.lsp.buf.rename(vim.fn.expand('<cword>')) end,
      desc = '󰈮 LSP Rename Word',
      mode = { 'n', 'v' },
    },
    {
      'gN',
      function() vim.lsp.buf.rename() end,
      desc = '󰈮 LSP Rename',
      mode = { 'n', 'v' },
    },
    {
      '<leader>fls',
      function() Snacks.picker.lsp_symbols() end,
      desc = '󰘧 LSP Symbols',
    },
    {
      '<leader>flS',
      require('custom.actions.workspace_symbols').show_workspace_symbols_with_cache,
      desc = '󰘧 LSP Workspace Symbols (Cached)',
    },
    {
      'gx',
      require('custom.actions.files').yank_word_and_open,
      desc = '󰏌 Open File Under Cursor',
      mode = { 'n', 'v' },
    },

    {
      '<leader>fff',
      function()
        Snacks.picker.smart({
          hidden = true,
          filter = { cwd = true },
          args = { '--no-ignore-vcs' },
        })
      end,
      desc = '󰈙 Smart Find Files',
    },
    {
      '<leader>fsg',
      function() Snacks.picker.grep({ hidden = true }) end,
      desc = '󰊄 Grep',
    },
    {
      '<leader>fvr',
      function() Snacks.picker.resume() end,
      desc = '󰻂 Resume',
    },
    {
      '<leader>fvu',
      function() Snacks.picker.undo() end,
      desc = '󰕘 Undo History',
    },
    {
      '<leader>fle',
      function() Snacks.picker.diagnostics() end,
      desc = '󰒡 Diagnostics',
    },
    {
      '<leader>fsw',
      function() Snacks.picker.grep_word() end,
      desc = '󰬴 Visual selection or word',
      mode = { 'n', 'x' },
    },
    {
      '<leader>fsT',
      require('custom.actions.text_search').search_user_text,
      desc = '󰗊 Search User-Facing Text',
    },
    {
      '<leader>fvn',
      function()
        Snacks.picker.notifications({
          preview = false,
          confirm = function(picker, item)
            picker:close()
            if item and item.text then
              vim.fn.setreg('+', item.text)
              Snacks.notify('Copied to clipboard')
            end
          end,
        })
      end,
      desc = '󰓕 Notification History',
    },
    {
      '<leader>ffN',
      function()
        Snacks.picker.files({
          dirs = { vim.fn.expand('~/Programming/JimmyTranDev/notes') },
          hidden = true,
        })
      end,
      desc = '󰎞 Find Notes Files',
    },
    {
      '<leader>fvc',
      function() Snacks.picker.commands() end,
      desc = '󰘳 Commands',
    },
    {
      '<leader>ffp',
      function()
        local cwd = vim.fn.getcwd()
        local dirs = {}
        for _, dir in ipairs({ 'plans', 'updates' }) do
          if vim.fn.isdirectory(cwd .. '/' .. dir) == 1 then table.insert(dirs, dir) end
        end
        if #dirs == 0 then
          vim.notify('No plans/ or updates/ directory in ' .. cwd, vim.log.levels.WARN)
          return
        end
        Snacks.picker.files({ dirs = dirs, ignored = true })
      end,
      desc = '󰈙 Find Plan & Update Files',
    },
    {
      '<leader>fgt',
      function() Snacks.picker.git_files() end,
      desc = '󰊢 Find Git Files',
    },
    {
      '<leader>fgb',
      function() Snacks.picker.git_branches() end,
      desc = '󰘬 Git Branches',
    },
    {
      '<leader>fgl',
      function() Snacks.picker.git_log() end,
      desc = '󰜎 Git Log',
    },
    {
      '<leader>fgL',
      function() Snacks.picker.git_log_line() end,
      desc = '󰜎 Git Log Line',
    },
    {
      '<leader>fgd',
      function() Snacks.picker.git_status() end,
      desc = '󰊢 Git Status',
    },
    {
      '<leader>fgS',
      function() Snacks.picker.git_stash() end,
      desc = '󰛆 Git Stash',
    },
    {
      '<leader>fgu',
      function() Snacks.picker.git_status() end,
      desc = '󰶟 Git Status (uncommitted changes)',
    },
    {
      '<leader>fgH',
      function()
        local ok, gs = pcall(require, 'gitsigns')
        if not ok then
          vim.notify('gitsigns not available', vim.log.levels.ERROR)
          return
        end

        local hunks = gs.get_hunks()
        if not hunks or #hunks == 0 then
          vim.notify('No hunks in current buffer', vim.log.levels.INFO)
          return
        end

        local items = {}
        local bufnr = vim.api.nvim_get_current_buf()
        local filepath = vim.api.nvim_buf_get_name(bufnr)
        local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

        for i, hunk in ipairs(hunks) do
          local start_line = hunk.added and hunk.added.start or 1
          local preview_line = lines[start_line] or ''
          local type_indicator = hunk.type == 'add' and '+' or (hunk.type == 'delete' and '-' or '~')
          table.insert(items, {
            idx = i,
            text = string.format('%s L%d: %s', type_indicator, start_line, preview_line:sub(1, 60)),
            file = filepath,
            pos = { start_line, 0 },
            line = start_line,
            hunk = hunk,
          })
        end

        Snacks.picker({
          title = 'Git Hunks (Current Buffer)',
          items = items,
          preview = 'file',
          format = function(item) return { { item.text, 'Normal' } } end,
          confirm = function(picker, item)
            picker:close()
            vim.api.nvim_win_set_cursor(0, { item.line, 0 })
          end,
        })
      end,
      desc = '󰶟 Find Hunks (Buffer)',
    },
    {
      '<leader>fgD',
      function()
        local ref = vim.fn.system('git rev-parse --verify origin/HEAD 2>/dev/null'):gsub('%s+', '')
        if vim.v.shell_error ~= 0 or ref == '' then
          ref = vim.fn.system('git rev-parse --verify origin/main 2>/dev/null'):gsub('%s+', '')
          if vim.v.shell_error ~= 0 or ref == '' then ref = vim.fn.system('git rev-parse --verify origin/master 2>/dev/null'):gsub('%s+', '') end
        end
        if vim.v.shell_error ~= 0 or ref == '' then
          vim.notify('Could not determine origin branch', vim.log.levels.ERROR)
          return
        end
        Snacks.picker.git_diff({ base = ref })
      end,
      desc = '󰶟 Git Diff vs Origin',
    },
    {
      '<leader>fgf',
      function() Snacks.picker.git_log_file() end,
      desc = '󰜎 Git Log File',
    },
    {
      '<leader>fgc',
      function() Snacks.picker.grep({ search = '<<<<<<<' }) end,
      desc = '󰘬 Find Git Conflicts',
    },
    {
      '<leader>fs/',
      function() Snacks.picker.search_history() end,
      desc = '󰋚 Search History',
    },
    {
      '<leader>fvC',
      function() Snacks.picker.command_history() end,
      desc = '󰘳 Command History',
    },
    {
      '<leader>fvi',
      function() Snacks.picker.icons() end,
      desc = '󰛓 Icons',
    },
    {
      '<leader>fvk',
      function() Snacks.picker.keymaps() end,
      desc = '󰌑 Keymaps',
    },
    {
      '<leader>fvP',
      require('custom.actions.packages').show_package_json_picker,
      desc = '󰎡 Package.json Packages',
    },
    {
      mode = 'n',
      '<leader>fsm',
      file_actions.grep_markdown_headings,
      desc = '󰪶 Find Markdown Headings',
      silent = true,
    },
    {
      '<leader>fst',
      require('custom.actions.language').fms_key_lookup,
      desc = '󰗊 FMS Text Lookup',
    },
    {
      '<leader>ffo',
      function()
        local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
        if vim.v.shell_error ~= 0 or not git_root or git_root == '' then
          Snacks.picker.recent()
          return
        end
        git_root = vim.fn.fnamemodify(git_root, ':p')
        Snacks.picker.recent({
          filter = { cwd = git_root },
        })
      end,
      desc = '󰋚 Recent (repo)',
    },
  },
}
