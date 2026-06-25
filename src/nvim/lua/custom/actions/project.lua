local async = require('custom.utils.async')
local files = require('custom.utils.files')
local ui = require('custom.utils.ui')
local usage_cache = require('custom.utils.usage_cache')

local M = {}

local PROGRAMMING_DIR = vim.fn.expand('$HOME/Programming')
local MAX_TAB_NAME_LENGTH = 20
-- Recency store namespace for the project switcher (most-recently-used order).
local PROJECT_USAGE_NS = 'projects'

--- Stable usage_cache key for a project/worktree entry (its absolute path).
---@param item { path: string }
---@return string
local function project_key(item) return item.path end

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
  if tab_index > 0 then tab_name = tab_index .. '.' .. tab_name end
  vim.fn.system('zellij action rename-tab "' .. tab_name .. '"')
end

function M.switch_project()
  -- Include wcreated/wcheckout worktrees (the legacy Worktrees dir stays excluded).
  local projects = files.scan_programming({ Worktrees = true })
  if #projects == 0 then return vim.notify('No projects found in ' .. PROGRAMMING_DIR, vim.log.levels.WARN) end

  -- Most-recently-used first; never-opened entries fall back to alphabetical.
  usage_cache.sort_by_recency(PROJECT_USAGE_NS, projects, project_key)

  local current_cwd = vim.fn.getcwd()

  ui.pick({
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
    on_confirm = function(item)
      if item.path == current_cwd then
        vim.notify('Already in ' .. item.text, vim.log.levels.INFO)
        return
      end
      usage_cache.record(PROJECT_USAGE_NS, project_key(item))
      vim.cmd('cd ' .. vim.fn.fnameescape(item.path))
      rename_zellij_tab(item.name)
      vim.notify('Switched to ' .. item.text, vim.log.levels.INFO)
    end,
  })
end

function M.copy_project_path()
  local projects = files.scan_programming()
  if #projects == 0 then return vim.notify('No projects found in ' .. PROGRAMMING_DIR, vim.log.levels.WARN) end

  ui.pick({
    title = 'Copy Project Path (' .. #projects .. ' projects)',
    items = projects,
    format = function(item)
      return {
        { item.org .. '/', 'Comment' },
        { item.name, 'Function' },
      }
    end,
    on_confirm = function(item)
      vim.fn.setreg('+', item.path)
      vim.notify('Copied: ' .. item.path, vim.log.levels.INFO)
    end,
  })
end

function M.pull_and_copy_project_path()
  local projects = files.scan_programming()
  if #projects == 0 then return vim.notify('No projects found in ' .. PROGRAMMING_DIR, vim.log.levels.WARN) end

  ui.pick({
    title = 'Pull & Copy Project Path (' .. #projects .. ' projects)',
    items = projects,
    format = function(item)
      return {
        { item.org .. '/', 'Comment' },
        { item.name, 'Function' },
      }
    end,
    on_confirm = function(item)
      local stat = vim.uv.fs_stat(item.path)
      if not stat or stat.type ~= 'directory' then
        vim.notify('Repo not found locally: ' .. item.path, vim.log.levels.WARN)
        return
      end

      vim.notify('Pulling ' .. item.text .. '...', vim.log.levels.INFO)
      async.run_cmd({ 'git', '-C', item.path, 'pull', '--ff-only' }, function(result)
        vim.fn.setreg('+', item.path)
        if result.code == 0 then
          vim.notify('Pulled & copied: ' .. item.path, vim.log.levels.INFO)
        else
          local err = result.stderr ~= '' and result.stderr or result.stdout
          vim.notify('Pull failed (path copied): ' .. err, vim.log.levels.WARN)
        end
      end)
    end,
  })
end

return M
