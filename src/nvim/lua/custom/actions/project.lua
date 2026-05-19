local M = {}

local PROGRAMMING_DIR = vim.fn.expand('$HOME/Programming')
local EXCLUDED_DIRS = { Worktrees = true, wcreated = true, wcheckout = true }

local function scan_projects()
  local projects = {}
  local org_dir = vim.uv.fs_scandir(PROGRAMMING_DIR)
  if not org_dir then return projects end

  while true do
    local org_name, org_type = vim.uv.fs_scandir_next(org_dir)
    if not org_name then break end
    if org_type == 'directory' and not EXCLUDED_DIRS[org_name] then
      local org_path = PROGRAMMING_DIR .. '/' .. org_name
      local repo_dir = vim.uv.fs_scandir(org_path)
      if repo_dir then
        while true do
          local repo_name, repo_type = vim.uv.fs_scandir_next(repo_dir)
          if not repo_name then break end
          if repo_type == 'directory' and not repo_name:match('^%.') then
            table.insert(projects, {
              org = org_name,
              name = repo_name,
              path = org_path .. '/' .. repo_name,
              text = org_name .. '/' .. repo_name,
            })
          end
        end
      end
    end
  end

  table.sort(projects, function(a, b) return a.text < b.text end)
  for i, p in ipairs(projects) do
    p.idx = i
  end
  return projects
end

function M.switch_project()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return vim.notify('Snacks not available', vim.log.levels.WARN) end

  local projects = scan_projects()
  if #projects == 0 then return vim.notify('No projects found in ' .. PROGRAMMING_DIR, vim.log.levels.WARN) end

  local current_cwd = vim.fn.getcwd()

  snacks.picker({
    title = 'Switch Project (' .. #projects .. ' projects)',
    items = projects,
    format = function(item)
      local is_current = item.path == current_cwd
      local indicator = is_current and ' ' or '  '
      return {
        { indicator, is_current and 'DiagnosticOk' or 'Comment' },
        { item.org .. '/', 'Comment' },
        { item.name, is_current and 'DiagnosticOk' or 'Function' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if item.path == current_cwd then
        vim.notify('Already in ' .. item.text, vim.log.levels.INFO)
        return
      end
      vim.cmd('cd ' .. vim.fn.fnameescape(item.path))
      vim.notify('Switched to ' .. item.text, vim.log.levels.INFO)
    end,
  })
end

return M
