local file_actions = require('custom.actions.files')

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

local function show_package_json_picker()
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



local function show_workspace_symbols_with_cache()
  local cache = require('custom.utils.workspace_symbol_cache')
  local cached = cache.get(300)
  if cached then
    return Snacks.picker({
      title = 'LSP Workspace Symbols (Cached)',
      items = cached,
      preview = 'file',
      format = function(item)
        local kind = item.kind or ''
        local name = item.name or ''
        local file = item.file or ''
        return {
          { kind .. ' ', 'Type' },
          { name .. ' ', 'Normal' },
          { vim.fn.fnamemodify(file, ':~:.'), 'Comment' },
        }
      end,
      confirm = function(picker, item)
        picker:close()
        if item.file and item.pos then
          vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
          pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] })
        end
      end,
    })
  end

  local buf = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = buf, method = 'workspace/symbol' })
  if #clients == 0 then
    Snacks.picker.lsp_workspace_symbols()
    return
  end

  local all_items = {}
  local pending = #clients

  for _, client in ipairs(clients) do
    client:request('workspace/symbol', { query = '' }, function(err, result)
      if not err and result then
        local lsp_mod = require('snacks.picker.source.lsp')
        local items = lsp_mod.results_to_items(client, result, { text_with_file = true })
        for _, item in ipairs(items) do
          table.insert(all_items, {
            text = item.text,
            file = item.file,
            pos = item.pos,
            kind = item.kind,
            name = item.name,
          })
        end
      end

      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          if #all_items > 0 then
            cache.set(all_items)
          end
          Snacks.picker({
            title = 'LSP Workspace Symbols',
            items = all_items,
            preview = 'file',
            format = function(item)
              local kind = item.kind or ''
              local name = item.name or ''
              local file = item.file or ''
              return {
                { kind .. ' ', 'Type' },
                { name .. ' ', 'Normal' },
                { vim.fn.fnamemodify(file, ':~:.'), 'Comment' },
              }
            end,
            confirm = function(picker, item)
              picker:close()
              if item.file and item.pos then
                vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
                pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] })
              end
            end,
          })
        end)
      end
    end, buf)
  end
end


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
      '<leader>fs',
      function() Snacks.picker.lsp_symbols() end,
      desc = '󰘧 LSP Symbols',
    },
    {
      '<leader>fS',
      show_workspace_symbols_with_cache,
      desc = '󰘧 LSP Workspace Symbols (Cached)',
    },
    {
      'gx',
      require('custom.actions.files').yank_word_and_open,
      desc = '󰏌 Open File Under Cursor',
      mode = { 'n', 'v' },
    },

    {
      '<leader>ff',
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
      '<leader>fg',
      function() Snacks.picker.grep({ hidden = true }) end,
      desc = '󰊄 Grep',
    },
    {
      '<leader>fr',
      function() Snacks.picker.resume() end,
      desc = '󰻂 Resume',
    },
    {
      '<leader>fu',
      function() Snacks.picker.undo() end,
      desc = '󰕘 Undo History',
    },
    {
      '<leader>fe',
      function() Snacks.picker.diagnostics() end,
      desc = '󰒡 Diagnostics',
    },
    {
      '<leader>fw',
      function() Snacks.picker.grep_word() end,
      desc = '󰬴 Visual selection or word',
      mode = { 'n', 'x' },
    },
    {
      '<leader>fT',
      require('custom.actions.text_search').search_user_text,
      desc = '󰗊 Search User-Facing Text',
    },
    {
      '<leader>fn',
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
      '<leader>fN',
      function()
        Snacks.picker.files({
          dirs = { vim.fn.expand('~/Programming/JimmyTranDev/notes') },
          hidden = true,
        })
      end,
      desc = '󰎞 Find Notes Files',
    },
    {
      '<leader>fc',
      function() Snacks.picker.commands() end,
      desc = '󰘳 Commands',
    },
    {
      '<leader>fp',
      function()
        local cwd = vim.fn.getcwd()
        local dirs = {}
        for _, dir in ipairs({ 'plans', 'updates' }) do
          if vim.fn.isdirectory(cwd .. '/' .. dir) == 1 then
            table.insert(dirs, dir)
          end
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
      '<leader>fjt',
      function() Snacks.picker.git_files() end,
      desc = '󰊢 Find Git Files',
    },
    {
      '<leader>fjb',
      function() Snacks.picker.git_branches() end,
      desc = '󰘬 Git Branches',
    },
    {
      '<leader>fjl',
      function() Snacks.picker.git_log() end,
      desc = '󰜎 Git Log',
    },
    {
      '<leader>fjL',
      function() Snacks.picker.git_log_line() end,
      desc = '󰜎 Git Log Line',
    },
    {
      '<leader>fjd',
      function() Snacks.picker.git_status() end,
      desc = '󰊢 Git Status',
    },
    {
      '<leader>fjS',
      function() Snacks.picker.git_stash() end,
      desc = '󰛆 Git Stash',
    },
    {
      '<leader>fd',
      function()
        Snacks.picker.git_status()
      end,
      desc = '󰶟 Git Status (uncommitted changes)',
    },
    {
      '<leader>fjH',
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
      '<leader>fjD',
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
      '<leader>fjf',
      function() Snacks.picker.git_log_file() end,
      desc = '󰜎 Git Log File',
    },
    {
      '<leader>fjc',
      function() Snacks.picker.grep({ search = '<<<<<<<' }) end,
      desc = '󰘬 Find Git Conflicts',
    },
    {
      '<leader>f/',
      function() Snacks.picker.search_history() end,
      desc = '󰋚 Search History',
    },
    {
      '<leader>fC',
      function() Snacks.picker.command_history() end,
      desc = '󰘳 Command History',
    },
    {
      '<leader>fi',
      function() Snacks.picker.icons() end,
      desc = '󰛓 Icons',
    },
    {
      '<leader>fk',
      function() Snacks.picker.keymaps() end,
      desc = '󰌑 Keymaps',
    },
    {
      '<leader>fP',
      show_package_json_picker,
      desc = '󰎡 Package.json Packages',
    },
    {
      mode = 'n',
      '<leader>fm',
      file_actions.grep_markdown_headings,
      desc = '󰪶 Find Markdown Headings',
      silent = true,
    },
    {
      '<leader>ft',
      require('custom.actions.language').fms_key_lookup,
      desc = '󰗊 FMS Text Lookup',
    },
    -- {
    --   '<leader>fE',
    --   show_diagnostics_picker,
    --   desc = '󰒡 Diagnostics',
    -- },
    -- {
    --   '<leader>fF',
    --   function() Snacks.picker.files({ hidden = true, filter = { cwd = true } }) end,
    --   desc = 'Find Files',
    -- },
    -- {
    --   '<leader>fC',
    --   function() Snacks.picker.files({ cwd = vim.fn.stdpath('config') }) end,
    --   desc = 'Find Config File',
    -- },
    -- {
    --   '<leader>fp',
    --   function() Snacks.picker.projects() end,
    --   desc = 'Projects',
    -- },
    {
      '<leader>fo',
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
    -- {
    --   '<leader>fl',
    --   function() Snacks.picker.lines() end,
    --   desc = 'Buffer Lines',
    -- },
    -- {
    --   '<leader>fvj',
    --   function() Snacks.picker.jumps() end,
    --   desc = 'Jumps',
    -- },
    -- {
    --   '<leader><leader>D',
    --   function() Snacks.terminal('lazydocker', { win = { style = 'float' } }) end,
    --   desc = 'Lazydocker',
    -- },
    -- {
    --   '<leader><leader>S',
    --   function() Snacks.terminal('lazysql', { win = { style = 'float' } }) end,
    --   desc = 'Lazysql',
    -- },
    -- {
    --   '<leader>;D',
    --   function() Snacks.terminal('vd ' .. vim.fn.expand('%'), { win = { style = 'float' } }) end,
    --   desc = 'Visidata',
    -- },
    -- {
    --   '<leader>gL',
    --   function() Snacks.gitbrowse() end,
    --   desc = 'Git Browse',
    --   mode = { 'n', 'v' },
    -- },
    -- {
    --   '<leader>fH',
    --   function() Snacks.picker.highlights() end,
    --   desc = 'Highlights',
    -- },
    -- {
    --   '<leader>fM',
    --   function() Snacks.picker.man() end,
    --   desc = 'Man Pages',
    -- },
    -- {
    --   '<leader>f"',
    --   function() Snacks.picker.registers() end,
    --   desc = 'Registers',
    -- },
    -- {
    --   '<leader>fva',
    --   function() Snacks.picker.autocmds() end,
    --   desc = 'Autocmds',
    -- },
    -- {
    --   '<leader>fvf',
    --   function() Snacks.picker.colorschemes() end,
    --   desc = 'Colorschemes',
    -- },
    -- {
    --   '<leader>fvh',
    --   function() Snacks.picker.help() end,
    --   desc = 'Help Pages',
    -- },
    -- {
    --   '<leader>fvl',
    --   function() Snacks.picker.loclist() end,
    --   desc = 'Location List',
    -- },
    -- {
    --   '<leader>fvm',
    --   function() Snacks.picker.marks() end,
    --   desc = 'Marks',
    -- },
    -- {
    --   '<leader>fvp',
    --   function() Snacks.picker.lazy() end,
    --   desc = 'Search for Plugin Spec',
    -- },
    -- {
    --   '<leader>fvq',
    --   function() Snacks.picker.qflist() end,
    --   desc = 'Quickfix List',
    -- },
    -- {
    --   '<leader>fN',
    --   desc = 'Neovim News',
    --   function()
    --     Snacks.win({
    --       file = vim.api.nvim_get_runtime_file('doc/news.txt', false)[1],
    --       width = 0.6,
    --       height = 0.6,
    --       wo = {
    --         spell = false,
    --         wrap = false,
    --         signcolumn = 'yes',
    --         statuscolumn = ' ',
    --         conceallevel = 3,
    --       },
    --     })
    --   end,
    -- },
  },
}
