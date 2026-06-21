local github_utils = require('custom.utils.github')
local file_utils = require('custom.utils.files')

local M = {}

-- ===========================================================================
-- Clone a remote repo into ~/Programming/<owner>/<repo>
-- Flow: pick GitHub owner -> pick repo -> clone into the owner's folder.
-- ===========================================================================

local PROGRAMMING_DIR = vim.fn.expand('$HOME/Programming')
local EXCLUDED_PROGRAMMING_DIRS = { Worktrees = true, wcreated = true, wcheckout = true }

--- List the top-level org/owner directories under ~/Programming.
---@return string[] sorted directory names
local function scan_programming_org_dirs()
  local dirs = {}
  for _, entry in ipairs(file_utils.scan(PROGRAMMING_DIR, { type = 'directory', exclude = EXCLUDED_PROGRAMMING_DIRS })) do
    table.insert(dirs, entry.name)
  end
  table.sort(dirs)
  return dirs
end

--- Clone `name_with_owner` into ~/Programming/<dest_folder>/<repo_name> via gh.
---@param name_with_owner string e.g. "JimmyTranDev/dotfiles"
---@param repo_name string the bare repo name used for the local directory
---@param dest_folder string the org folder under ~/Programming to clone into
local function clone_repo(name_with_owner, repo_name, dest_folder)
  local parent = PROGRAMMING_DIR .. '/' .. dest_folder
  local dest = parent .. '/' .. repo_name

  if vim.uv.fs_stat(dest) then
    vim.notify('Destination already exists: ' .. dest, vim.log.levels.WARN)
    return
  end

  if vim.fn.mkdir(parent, 'p') == 0 then
    vim.notify('Could not create folder: ' .. parent, vim.log.levels.ERROR)
    return
  end

  vim.notify('Cloning ' .. name_with_owner .. '...', vim.log.levels.INFO)
  vim.system(
    { 'gh', 'repo', 'clone', name_with_owner, dest },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 then
        vim.notify('Cloned ' .. name_with_owner .. ' to ' .. dest, vim.log.levels.INFO)
      else
        local err = (result.stderr and result.stderr ~= '' and result.stderr) or result.stdout or 'unknown error'
        vim.notify('Clone failed: ' .. err, vim.log.levels.ERROR)
      end
    end)
  )
end

--- Prompt for a destination folder under ~/Programming, then clone.
--- Existing org folders are offered, plus the repo owner as a new folder.
---@param name_with_owner string
---@param repo_name string
---@param owner string
local function select_destination_and_clone(name_with_owner, repo_name, owner)
  local choices = {}
  local seen = {}

  for _, dir in ipairs(scan_programming_org_dirs()) do
    seen[dir] = true
    table.insert(choices, { label = dir, folder = dir })
  end

  if owner and owner ~= '' and not seen[owner] then table.insert(choices, 1, { label = owner .. ' (new folder)', folder = owner }) end

  if #choices == 0 then
    vim.notify('No destination folders available under ' .. PROGRAMMING_DIR, vim.log.levels.ERROR)
    return
  end

  vim.ui.select(choices, {
    prompt = string.format('Clone into ~/Programming/<folder>/%s:', repo_name),
    format_item = function(item) return item.label end,
  }, function(choice)
    if not choice then return end
    clone_repo(name_with_owner, repo_name, choice.folder)
  end)
end

--- Clone a repo straight into ~/Programming/<owner>/<repo>, deriving the
--- destination folder from the repo's owner (no folder prompt).
---@param name_with_owner string e.g. "JimmyTranDev/dotfiles"
---@param repo_name string the bare repo name used for the local directory
---@param owner string fallback owner when name_with_owner has no owner segment
local function clone_repo_into_owner_folder(name_with_owner, repo_name, owner)
  local dest_folder = name_with_owner:match('^([^/]+)/') or owner
  clone_repo(name_with_owner, repo_name, dest_folder)
end

--- Fetch the owner's repos and present a picker to choose one to clone.
---@param owner string GitHub owner/org login
local function select_repo_and_clone(owner)
  vim.notify('Fetching repos for ' .. owner .. '...', vim.log.levels.INFO)
  vim.system(
    { 'gh', 'repo', 'list', owner, '--limit', '200', '--json', 'name,nameWithOwner,description,isPrivate' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        vim.notify('Failed to fetch repositories for ' .. owner .. ': ' .. (result.stderr or ''), vim.log.levels.ERROR)
        return
      end

      local ok, repos = pcall(vim.json.decode, result.stdout)
      if not ok or type(repos) ~= 'table' or #repos == 0 then
        vim.notify('No repositories found for ' .. owner, vim.log.levels.WARN)
        return
      end

      table.sort(repos, function(a, b) return a.name < b.name end)

      local items = {}
      for i, repo in ipairs(repos) do
        table.insert(items, {
          idx = i,
          text = repo.name,
          name = repo.name,
          name_with_owner = repo.nameWithOwner,
          description = repo.description or '',
          is_private = repo.isPrivate,
        })
      end

      local snacks_ok, snacks = pcall(require, 'snacks')
      if not snacks_ok then
        vim.ui.select(items, {
          prompt = 'Select repository to clone:',
          format_item = function(item) return item.name end,
        }, function(item)
          if not item then return end
          clone_repo_into_owner_folder(item.name_with_owner, item.name, owner)
        end)
        return
      end

      snacks.picker({
        title = string.format('Clone Repo from %s (%d)', owner, #items),
        items = items,
        format = function(item)
          local parts = { { item.name, 'Function' } }
          if item.is_private then table.insert(parts, { '  (private)', 'WarningMsg' }) end
          if item.description ~= '' then table.insert(parts, { '  ' .. item.description, 'Comment' }) end
          return parts
        end,
        confirm = function(picker, item)
          picker:close()
          clone_repo_into_owner_folder(item.name_with_owner, item.name, owner)
        end,
      })
    end)
  )
end

--- Entry point: pick a GitHub owner (auto-skipped when only one), then a repo,
--- then clone it into ~/Programming/<owner>/<repo> (folder derived from owner).
function M.select_owner_repo_and_clone()
  local owners = github_utils.get_github_owners()
  if #owners == 0 then
    vim.notify('No GitHub owners configured (set ORG_GITHUB_NAME or PRI_GITHUB_USERNAME)', vim.log.levels.ERROR)
    return
  end

  if #owners == 1 then
    select_repo_and_clone(owners[1])
    return
  end

  vim.ui.select(owners, {
    prompt = 'Select owner:',
  }, function(owner)
    if not owner then return end
    select_repo_and_clone(owner)
  end)
end

-- ===========================================================================
-- Create a new private repo under a GitHub owner, then clone it locally.
-- Flow: pick owner -> name the repo -> gh repo create -> pick folder -> clone.
-- ===========================================================================

--- Create `owner/name` as a private repo (with a README) then clone it into
--- ~/Programming/<folder>/<repo> by reusing the destination picker.
---@param owner string GitHub owner/org login
---@param name string bare repo name to create
local function create_repo_and_clone(owner, name)
  local name_with_owner = owner .. '/' .. name

  vim.notify('Creating ' .. name_with_owner .. '...', vim.log.levels.INFO)
  vim.system(
    { 'gh', 'repo', 'create', name_with_owner, '--private', '--add-readme' },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        local err = (result.stderr and result.stderr ~= '' and result.stderr) or result.stdout or 'unknown error'
        vim.notify('Repo creation failed: ' .. err, vim.log.levels.ERROR)
        return
      end

      vim.notify('Created ' .. name_with_owner, vim.log.levels.INFO)
      select_destination_and_clone(name_with_owner, name, owner)
    end)
  )
end

--- Prompt for a repo name under `owner`, then create and clone it.
---@param owner string GitHub owner/org login
local function prompt_name_and_create(owner)
  vim.ui.input({ prompt = string.format('New repo name (%s/): ', owner) }, function(name)
    if not name then return end
    name = vim.trim(name)
    if name == '' then return end
    create_repo_and_clone(owner, name)
  end)
end

--- Entry point: pick a GitHub owner (auto-skipped when only one), name a new
--- private repo, create it on GitHub, then clone it under ~/Programming.
function M.create_owner_repo_and_clone()
  local owners = github_utils.get_github_owners()
  if #owners == 0 then
    vim.notify('No GitHub owners configured (set ORG_GITHUB_NAME or PRI_GITHUB_USERNAME)', vim.log.levels.ERROR)
    return
  end

  if #owners == 1 then
    prompt_name_and_create(owners[1])
    return
  end

  vim.ui.select(owners, {
    prompt = 'Select owner:',
  }, function(owner)
    if not owner then return end
    prompt_name_and_create(owner)
  end)
end

return M
