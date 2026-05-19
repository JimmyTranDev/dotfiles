local M = {}

function M.list_files(dir)
  if type(dir) ~= 'string' then return {} end
  local result = vim.fn.systemlist('ls -t ' .. vim.fn.shellescape(dir))
  return vim.v.shell_error == 0 and result or {}
end

function M.open(item)
  if type(item) ~= 'string' then
    vim.notify('Invalid item to open', vim.log.levels.ERROR)
    return
  end

  local escaped = vim.fn.shellescape(item)
  local cmd = vim.fn.has('mac') == 1 and 'open '
    or vim.fn.has('wsl') == 1 and 'cmd.exe /c start '
    or vim.fn.has('win32') == 1 and 'start '
    or vim.fn.has('unix') == 1 and 'xdg-open '
    or nil

  if cmd then
    vim.fn.system(cmd .. escaped)
  else
    vim.notify('Unsupported operating system', vim.log.levels.ERROR)
  end
end

function M.read_lines(filepath)
  local lines = {}
  local f = io.open(filepath, 'r')
  if f then
    for line in f:lines() do
      table.insert(lines, line)
    end
    f:close()
  end
  return lines
end

function M.write_lines(filepath, lines)
  local f = io.open(filepath, 'w')
  if f then
    f:write(table.concat(lines, '\n') .. '\n')
    f:close()
    return true
  end
  return false
end

function M.ensure_directory_exists(filepath)
  local dir = vim.fn.fnamemodify(filepath, ':h')
  if vim.fn.isdirectory(dir) == 0 then vim.fn.mkdir(dir, 'p') end
end

function M.get_recursive_file_contents()
  local current_dir = vim.fn.fnamemodify(vim.fn.expand('%:p'), ':h')
  local content = {}

  local function process_dir(dir, prefix)
    for _, item in ipairs(vim.fn.glob(dir .. '/*', false, true)) do
      if vim.fn.isdirectory(item) == 1 then
        table.insert(content, prefix .. '=== Directory: ' .. vim.fn.fnamemodify(item, ':t') .. ' ===')
        table.insert(content, '')
        process_dir(item, prefix .. '  ')
      else
        local ok, file_content = pcall(vim.fn.readfile, item)
        if ok then
          table.insert(content, prefix .. '=== ' .. vim.fn.fnamemodify(item, ':t') .. ' ===')
          vim.list_extend(content, file_content)
          table.insert(content, '')
        end
      end
    end
  end

  process_dir(current_dir, '')
  return table.concat(content, '\n')
end

return M
