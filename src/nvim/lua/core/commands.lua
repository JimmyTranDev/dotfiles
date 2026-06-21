local M = {}

local function augroup(name) return vim.api.nvim_create_augroup('nvim_config_' .. name, { clear = true }) end

local function setup_filetype_associations()
  vim.api.nvim_create_autocmd('BufRead', {
    group = augroup('filetype_associations'),
    pattern = { '*.tag', '*.riot' },
    callback = function() vim.bo.filetype = 'html' end,
    desc = '󰌐 Set HTML filetype for Riot.js component files',
  })
end

local function setup_language_settings()
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup('language_settings'),
    pattern = 'java',
    callback = function()
      vim.bo.shiftwidth = 4
      vim.bo.tabstop = 4
      vim.bo.softtabstop = 4
    end,
    desc = '󰬦 Set Java-specific indentation (4 spaces)',
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup('markdown_wrap'),
    callback = function() vim.wo.wrap = vim.bo.filetype == 'markdown' end,
    desc = '󰱤 Enable soft wrap only for markdown files',
  })
end

local function setup_visual_enhancements()
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = augroup('visual_enhancements'),
    pattern = '*',
    callback = function() vim.highlight.on_yank({ higroup = 'Visual', timeout = 200 }) end,
    desc = '󰅗 Highlight yanked text briefly',
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = augroup('copilot_settings'),
    pattern = 'copilot-*',
    callback = function() vim.opt_local.relativenumber = true end,
    desc = '󰌑 Enable relative line numbers in Copilot buffers',
  })
end

local function setup_git_integration()
  vim.api.nvim_create_autocmd('User', {
    group = augroup('git_integration'),
    pattern = 'GitConflictDetected',
    callback = function()
      vim.notify('Git conflict detected in: ' .. vim.fn.expand('<afile>'), vim.log.levels.WARN)
      vim.keymap.set(
        'n',
        'cww',
        function() vim.notify('Git conflict resolution functionality not yet implemented', vim.log.levels.INFO) end,
        { buffer = true, desc = '󰘬 Resolve git conflicts' }
      )
    end,
    desc = '󰘻 Handle git conflict detection and setup resolution keymaps',
  })
end

local function setup_lsp_progress()
  local progress = vim.defaulttable()
  local spinner = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

  vim.api.nvim_create_autocmd('LspProgress', {
    group = augroup('lsp_progress'),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      local value = ev.data.params.value
      if not client or type(value) ~= 'table' then return end

      local p = progress[client.id]
      for i = 1, #p + 1 do
        if i == #p + 1 or p[i].token == ev.data.params.token then
          p[i] = {
            token = ev.data.params.token,
            msg = ('[%3d%%] %s%s'):format(
              value.kind == 'end' and 100 or value.percentage or 100,
              value.title or '',
              value.message and (' **%s**'):format(value.message) or ''
            ),
            done = value.kind == 'end',
          }
          break
        end
      end

      local msg = {}
      progress[client.id] = vim.tbl_filter(function(v)
        table.insert(msg, v.msg)
        return not v.done
      end, p)

      local idx = math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1
      vim.notify(table.concat(msg, '\n'), vim.log.levels.INFO, {
        id = 'lsp_progress',
        title = client.name,
        opts = function(notif) notif.icon = #progress[client.id] == 0 and ' ' or spinner[idx] end,
      })
    end,
    desc = '󰗖 Show LSP progress notifications with spinner',
  })
end

local function cleanup_default_keymaps()
  for _, m in ipairs({ 'gra', 'gri', 'grn', 'grr' }) do
    pcall(vim.keymap.del, 'n', m)
  end
end

local function setup_workspace_symbol_cache_commands()
  local ok, cache = pcall(require, 'custom.utils.workspace_symbol_cache')
  if not ok then
    vim.notify('Failed to load workspace symbol cache utility', vim.log.levels.WARN)
    return
  end

  vim.api.nvim_create_user_command('ClearSymbolCache', function()
    if cache.clear() then
      vim.notify('Cleared workspace symbol cache', vim.log.levels.INFO)
    else
      vim.notify('Cache already cleared or never created', vim.log.levels.DEBUG)
    end
  end, { desc = 'Clear workspace symbols cache for current directory' })

  vim.api.nvim_create_user_command('ClearAllSymbolCache', function()
    if cache.clear_all() then
      vim.notify('Cleared all workspace symbol caches', vim.log.levels.INFO)
    else
      vim.notify('All caches already cleared or never created', vim.log.levels.DEBUG)
    end
  end, { desc = 'Clear all workspace symbols caches' })

  local prewarm_done = {}

  vim.api.nvim_create_autocmd('LspAttach', {
    group = augroup('workspace_symbol_prewarm'),
    callback = function(ev)
      local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p')
      if prewarm_done[cwd] then return end

      local cached = cache.get(300)
      if cached then
        prewarm_done[cwd] = true
        return
      end

      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client or not client:supports_method('workspace/symbol') then return end

      prewarm_done[cwd] = true

      vim.defer_fn(function()
        local buf = ev.buf
        if not vim.api.nvim_buf_is_valid(buf) then return end

        client:request('workspace/symbol', { query = '' }, function(err, result)
          if err or not result then return end

          local ok_lsp, lsp_mod = pcall(require, 'snacks.picker.source.lsp')
          if not ok_lsp then return end

          local items = lsp_mod.results_to_items(client, result, { text_with_file = true })
          local cache_items = {}
          for _, item in ipairs(items) do
            table.insert(cache_items, {
              text = item.text,
              file = item.file,
              pos = item.pos,
              kind = item.kind,
              name = item.name,
            })
          end

          if #cache_items > 0 then
            cache.set(cache_items)
          end
        end, buf)
      end, 3000)
    end,
    desc = 'Pre-warm workspace symbols cache on LSP attach',
  })
end

local function setup_auto_refresh()
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter', 'CursorHold', 'CursorHoldI' }, {
    group = augroup('auto_refresh'),
    pattern = '*',
    callback = function()
      if vim.fn.getcmdwintype() == '' then vim.cmd('silent! checktime') end
    end,
    desc = '󰆓 Check for external file changes and reload buffers',
  })

  vim.api.nvim_create_autocmd('FileChangedShellPost', {
    group = augroup('auto_refresh_notify'),
    pattern = '*',
    callback = function() vim.cmd('silent! checktime') end,
    desc = '󰇥 Silently reload buffer when file changes on disk',
  })
end

local function setup_toggleterm_whichkey_fix()
  -- Snappy default; widened window while a terminal CLI is producing output.
  local BASE_TIMEOUTLEN = 300
  local TERMINAL_TIMEOUTLEN = 1000

  -- True while any terminal buffer still has a live job. Heavy CLI output
  -- keeps the main loop busy, so the gap before the next key is registered can
  -- exceed 'timeoutlen' and a half-typed <leader> sequence resolves alone.
  local function has_live_terminal()
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == 'terminal' then
        local chan = vim.b[buf].terminal_job_id
        if chan and vim.fn.jobwait({ chan }, 0)[1] == -1 then return true end
      end
    end
    return false
  end

  local function apply_timeout()
    vim.o.timeout = true
    vim.o.timeoutlen = has_live_terminal() and TERMINAL_TIMEOUTLEN or BASE_TIMEOUTLEN
  end

  vim.api.nvim_create_autocmd({ 'TermOpen', 'TermClose' }, {
    group = augroup('toggleterm_whichkey'),
    callback = function() vim.schedule(apply_timeout) end,
    desc = '󰅗 Widen leader-timeout while a terminal CLI runs',
  })

  vim.api.nvim_create_autocmd('ModeChanged', {
    group = augroup('toggleterm_whichkey_mode'),
    pattern = 't:n',
    callback = function() vim.schedule(apply_timeout) end,
    desc = '󰗖 Re-evaluate leader-timeout when leaving terminal mode',
  })
end

local function setup_spell()
  vim.api.nvim_create_autocmd('FileType', {
    group = augroup('spell_check'),
    pattern = { 'gitcommit', 'text', 'plaintex', 'tex' },
    callback = function() vim.opt_local.spell = true end,
    desc = '󰓎 Enable spell check for text-heavy filetypes',
  })
end

function M.setup()
  setup_filetype_associations()
  setup_language_settings()
  setup_spell()
  setup_visual_enhancements()
  setup_git_integration()
  setup_lsp_progress()
  setup_auto_refresh()
  setup_toggleterm_whichkey_fix()
  setup_workspace_symbol_cache_commands()
  cleanup_default_keymaps()
end

M.setup()

return M
