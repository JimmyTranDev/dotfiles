local M = {}

local health_win = nil

local function get_lsp_status()
  local clients = vim.lsp.get_clients({ bufnr = 0 })
  if #clients == 0 then return { '  LSP: No active clients', 'DiagnosticWarn' } end
  local names = {}
  for _, client in ipairs(clients) do
    table.insert(names, client.name)
  end
  return { '  LSP: ' .. table.concat(names, ', '), 'DiagnosticOk' }
end

local function get_treesitter_status()
  local buf = vim.api.nvim_get_current_buf()
  local lang = vim.treesitter.language.get_lang(vim.bo[buf].filetype)
  if not lang then return { '  Treesitter: No parser for ' .. vim.bo[buf].filetype, 'DiagnosticWarn' } end
  local ok = pcall(vim.treesitter.get_parser, buf, lang)
  if ok then return { '  Treesitter: ' .. lang .. ' (active)', 'DiagnosticOk' } end
  return { '  Treesitter: ' .. lang .. ' (parser not loaded)', 'DiagnosticWarn' }
end

local function get_formatter_status()
  local ok, conform = pcall(require, 'conform')
  if not ok then return { '  Formatters: conform.nvim not available', 'DiagnosticWarn' } end

  local formatters = conform.list_formatters(0)
  if #formatters == 0 then return { '  Formatters: None configured for ' .. vim.bo.filetype, 'DiagnosticWarn' } end

  local names = {}
  local has_missing = false
  for _, f in ipairs(formatters) do
    local available = f.available ~= false
    if not available then has_missing = true end
    table.insert(names, f.name .. (available and '' or ' (missing)'))
  end
  local hl = has_missing and 'DiagnosticWarn' or 'DiagnosticOk'
  return { '  Formatters: ' .. table.concat(names, ', '), hl }
end

local function get_mason_status()
  local ok, registry = pcall(require, 'mason-registry')
  if not ok then return { '  Mason: not available', 'DiagnosticWarn' } end

  local installed = registry.get_installed_packages()
  local count = #installed
  return { '  Mason: ' .. count .. ' packages installed', 'DiagnosticOk' }
end

local function get_knip_status(callback)
  if vim.fn.executable('npx') ~= 1 then
    callback({ '  Knip: npx not available', 'DiagnosticHint' })
    return
  end

  vim.system(
    { 'npx', 'knip', '--no-progress', '--reporter', 'summary' },
    { text = true, timeout = 15000 },
    vim.schedule_wrap(function(result)
      if result.code == 0 or result.code == 1 then
        local issues = (result.stdout or ''):match('(%d+) issue')
        if issues and tonumber(issues) > 0 then
          callback({ '  Knip: ' .. issues .. ' unused code issues', 'DiagnosticWarn' })
        else
          callback({ '  Knip: Clean (no unused code)', 'DiagnosticOk' })
        end
      else
        callback({ '  Knip: Not available or failed', 'DiagnosticHint' })
      end
    end)
  )
end

local function get_diagnostic_summary()
  local counts = { 0, 0, 0, 0 }
  local diagnostics = vim.diagnostic.get(nil)
  for _, d in ipairs(diagnostics) do
    local sev = d.severity
    if sev >= 1 and sev <= 4 then counts[sev] = counts[sev] + 1 end
  end

  local parts = {}
  local labels = { 'Error', 'Warn', 'Info', 'Hint' }
  for i, label in ipairs(labels) do
    if counts[i] > 0 then table.insert(parts, label .. ': ' .. counts[i]) end
  end

  if #parts == 0 then return { '  Diagnostics: Clean', 'DiagnosticOk' } end

  local hl = counts[1] > 0 and 'DiagnosticError' or 'DiagnosticWarn'
  return { '  Diagnostics: ' .. table.concat(parts, ', '), hl }
end

local function get_git_status(callback)
  vim.system(
    { 'git', 'rev-parse', '--is-inside-work-tree' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        callback({ '  Git: Not a git repository', 'DiagnosticHint' })
        return
      end

      vim.system(
        { 'git', 'status', '--porcelain' },
        { text = true },
        vim.schedule_wrap(function(status_result)
          if status_result.code ~= 0 then
            callback({ '  Git: Error getting status', 'DiagnosticWarn' })
            return
          end

          local count = 0
          for _ in (status_result.stdout or ''):gmatch('[^\n]+') do
            count = count + 1
          end

          if count == 0 then
            callback({ '  Git: Working tree clean', 'DiagnosticOk' })
          else
            callback({ '  Git: ' .. count .. ' changed files', 'DiagnosticWarn' })
          end
        end)
      )
    end)
  )
end

function M.workspace_health()
  if health_win and vim.api.nvim_win_is_valid(health_win) then
    vim.api.nvim_win_close(health_win, true)
    health_win = nil
  end

  local lines = {}
  local async_results = { nil, nil }
  local pending = 2

  table.insert(lines, { '── Workspace Health ──', 'Title' })
  table.insert(lines, { '', nil })
  table.insert(lines, get_lsp_status())
  table.insert(lines, get_treesitter_status())
  table.insert(lines, get_diagnostic_summary())
  table.insert(lines, get_formatter_status())
  table.insert(lines, get_mason_status())

  local function maybe_show()
    pending = pending - 1
    if pending > 0 then return end

    for _, r in ipairs(async_results) do
      if r then table.insert(lines, r) end
    end

    local buf = vim.api.nvim_create_buf(false, true)
    local content = {}
    local highlights = {}

    for i, line in ipairs(lines) do
      table.insert(content, line[1])
      if line[2] then table.insert(highlights, { i - 1, line[2] }) end
    end

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, content)
    vim.bo[buf].modifiable = false
    vim.bo[buf].bufhidden = 'wipe'
    vim.bo[buf].buftype = 'nofile'

    local width = 60
    for _, line in ipairs(content) do
      width = math.max(width, #line + 4)
    end
    width = math.min(width, math.floor(vim.o.columns * 0.8))

    local height = #content
    local max_height = math.floor(vim.o.lines * 0.6)
    height = math.min(height, max_height)

    local win = vim.api.nvim_open_win(buf, true, {
      relative = 'editor',
      width = width,
      height = height,
      col = math.floor((vim.o.columns - width) / 2),
      row = math.floor((vim.o.lines - height) / 2),
      style = 'minimal',
      border = 'rounded',
      title = ' Health Check ',
      title_pos = 'center',
    })

    health_win = win

    for _, hl in ipairs(highlights) do
      vim.api.nvim_buf_add_highlight(buf, -1, hl[2], hl[1], 0, -1)
    end

    local function close_win()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
        health_win = nil
      end
    end

    vim.keymap.set('n', 'q', close_win, { buffer = buf, nowait = true })
    vim.keymap.set('n', '<Esc>', close_win, { buffer = buf, nowait = true })
  end

  get_git_status(function(r)
    async_results[1] = r
    maybe_show()
  end)

  get_knip_status(function(r)
    async_results[2] = r
    maybe_show()
  end)
end

return M
