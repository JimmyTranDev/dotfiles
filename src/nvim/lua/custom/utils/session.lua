local M = {}

local SESSION_DIR = vim.fn.stdpath('data') .. '/sessions'

local function ensure_session_dir() vim.fn.mkdir(SESSION_DIR, 'p') end

local function get_session_file()
  local cwd = vim.fn.getcwd()
  local name = cwd:gsub('[/\\:]+', '%%')
  return SESSION_DIR .. '/' .. name .. '.vim'
end

function M.save()
  ensure_session_dir()
  local file = get_session_file()
  vim.cmd('mksession! ' .. vim.fn.fnameescape(file))
end

function M.restore()
  local file = get_session_file()
  if vim.fn.filereadable(file) == 1 then
    vim.cmd('source ' .. vim.fn.fnameescape(file))
    vim.notify('Session restored', vim.log.levels.INFO)
    return true
  end
  vim.notify('No session found for this project', vim.log.levels.INFO)
  return false
end

function M.delete()
  local file = get_session_file()
  if vim.fn.filereadable(file) == 1 then
    os.remove(file)
    vim.notify('Session deleted', vim.log.levels.INFO)
  else
    vim.notify('No session to delete', vim.log.levels.INFO)
  end
end

function M.setup_autosave()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if vim.fn.argc() == 0 then return end
      local bufs = vim.fn.getbufinfo({ buflisted = 1 })
      if #bufs > 1 then M.save() end
    end,
  })
end

function M.list_sessions()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return vim.notify('Snacks not available', vim.log.levels.WARN) end

  ensure_session_dir()
  local files = vim.fn.globpath(SESSION_DIR, '*.vim', false, true)
  if #files == 0 then return vim.notify('No saved sessions', vim.log.levels.INFO) end

  local items = {}
  for _, file in ipairs(files) do
    local basename = vim.fn.fnamemodify(file, ':t:r')
    local path = basename:gsub('%%', '/')
    local stat = vim.uv.fs_stat(file)
    local mtime = stat and stat.mtime and stat.mtime.sec or 0
    table.insert(items, {
      text = path,
      file = file,
      path = path,
      mtime = mtime,
      idx = #items + 1,
    })
  end

  table.sort(items, function(a, b) return a.mtime > b.mtime end)
  for i, item in ipairs(items) do
    item.idx = i
  end

  snacks.picker({
    title = 'Sessions (' .. #items .. ')',
    items = items,
    format = function(item)
      local date = item.mtime > 0 and os.date('%Y-%m-%d %H:%M', item.mtime) or 'unknown'
      local is_current = item.path == vim.fn.getcwd()
      return {
        { is_current and ' ' or '  ', is_current and 'DiagnosticOk' or 'Comment' },
        { item.path, is_current and 'DiagnosticOk' or 'Function' },
        { '  ' },
        { date, 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.cmd('cd ' .. vim.fn.fnameescape(item.path))
      vim.cmd('source ' .. vim.fn.fnameescape(item.file))
      vim.notify('Restored session: ' .. item.path, vim.log.levels.INFO)
    end,
  })
end

return M
