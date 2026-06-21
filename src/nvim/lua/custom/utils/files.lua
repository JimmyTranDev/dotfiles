local M = {}

local PROGRAMMING_DIR = vim.fn.expand('$HOME/Programming')
local PROGRAMMING_EXCLUDE = { Worktrees = true, wcreated = true, wcheckout = true }

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

--- One-level scan of a directory. exclude may be a set { name = true } or a
--- predicate(name) -> boolean. Hidden (dot) entries are skipped unless hidden=true.
---@param dir string
---@param opts? { type?: 'directory'|'file', exclude?: table|fun(name: string): boolean, hidden?: boolean }
---@return { name: string, path: string, type: string }[]
function M.scan(dir, opts)
  opts = opts or {}
  local out, handle = {}, vim.uv.fs_scandir(dir)
  if not handle then return out end
  while true do
    local name, t = vim.uv.fs_scandir_next(handle)
    if not name then break end
    local excluded = type(opts.exclude) == 'function' and opts.exclude(name) or (type(opts.exclude) == 'table' and opts.exclude[name])
    local hidden = not opts.hidden and name:match('^%.')
    if (not opts.type or opts.type == t) and not excluded and not hidden then out[#out + 1] = { name = name, path = dir .. '/' .. name, type = t } end
  end
  return out
end

--- Two-level org/repo walk of ~/Programming. Hidden orgs are kept but hidden
--- repos are skipped (matching the historical project scan). Returns items
--- { org, name, path, text = 'org/name' } sorted by text.
---@param exclude? table org dir names to skip (default { Worktrees, wcreated, wcheckout })
---@return { org: string, name: string, path: string, text: string }[]
function M.scan_programming(exclude)
  exclude = exclude or PROGRAMMING_EXCLUDE
  local projects = {}
  for _, org in ipairs(M.scan(PROGRAMMING_DIR, { type = 'directory', exclude = exclude, hidden = true })) do
    for _, repo in ipairs(M.scan(org.path, { type = 'directory' })) do
      projects[#projects + 1] = { org = org.name, name = repo.name, path = repo.path, text = org.name .. '/' .. repo.name }
    end
  end
  table.sort(projects, function(a, b) return a.text < b.text end)
  return projects
end

return M
