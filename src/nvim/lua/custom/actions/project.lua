local M = {}

local PROGRAMMING_DIR = vim.fn.expand('$HOME/Programming')
local EXCLUDED_DIRS = { Worktrees = true, wcreated = true, wcheckout = true }
local MAX_TAB_NAME_LENGTH = 20

local function rename_zellij_tab(name)
  if not vim.env.ZELLIJ then return end

  local tab_name = name:sub(1, MAX_TAB_NAME_LENGTH)
  local layout = vim.fn.system('zellij action dump-layout 2>/dev/null')
  local tab_index = 0
  for line in layout:gmatch('[^\n]+') do
    if line:match('^%s*tab%s.*name=') then
      tab_index = tab_index + 1
      if line:match('focus=true') then break end
    end
  end
  if tab_index > 0 then
    tab_name = tab_index .. '.' .. tab_name
  end
  vim.fn.system('zellij action rename-tab "' .. tab_name .. '"')
end

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
      rename_zellij_tab(item.name)
      vim.notify('Switched to ' .. item.text, vim.log.levels.INFO)
    end,
  })
end

function M.copy_project_path()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return vim.notify('Snacks not available', vim.log.levels.WARN) end

  local projects = scan_projects()
  if #projects == 0 then return vim.notify('No projects found in ' .. PROGRAMMING_DIR, vim.log.levels.WARN) end

  snacks.picker({
    title = 'Copy Project Path (' .. #projects .. ' projects)',
    items = projects,
    format = function(item)
      return {
        { item.org .. '/', 'Comment' },
        { item.name, 'Function' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      vim.fn.setreg('+', item.path)
      vim.notify('Copied: ' .. item.path, vim.log.levels.INFO)
    end,
  })
end

function M.pull_and_copy_project_path()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then return vim.notify('Snacks not available', vim.log.levels.WARN) end

  local projects = scan_projects()
  if #projects == 0 then return vim.notify('No projects found in ' .. PROGRAMMING_DIR, vim.log.levels.WARN) end

  snacks.picker({
    title = 'Pull & Copy Project Path (' .. #projects .. ' projects)',
    items = projects,
    format = function(item)
      return {
        { item.org .. '/', 'Comment' },
        { item.name, 'Function' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      local stat = vim.uv.fs_stat(item.path)
      if not stat or stat.type ~= 'directory' then
        vim.notify('Repo not found locally: ' .. item.path, vim.log.levels.WARN)
        return
      end

      vim.notify('Pulling ' .. item.text .. '...', vim.log.levels.INFO)
      vim.system(
        { 'git', '-C', item.path, 'pull', '--ff-only' },
        { text = true },
        vim.schedule_wrap(function(result)
          vim.fn.setreg('+', item.path)
          if result.code == 0 then
            vim.notify('Pulled & copied: ' .. item.path, vim.log.levels.INFO)
          else
            local err = result.stderr ~= '' and result.stderr or result.stdout
            vim.notify('Pull failed (path copied): ' .. err, vim.log.levels.WARN)
          end
        end)
      )
    end,
  })
end

return M
