local git_utils = require('custom.utils.git')
local file_utils = require('custom.utils.files')
local github_utils = require('custom.utils.github')

local M = {}

local function get_pr_for_branch(branch)
  local pr_list_json = vim.fn.system('gh pr list --json number,headRefName,url')
  if vim.v.shell_error ~= 0 or not pr_list_json or pr_list_json == '' then return nil end

  local ok, pr_list = pcall(vim.json.decode, pr_list_json)
  if not ok or not pr_list then return nil end

  for _, pr in ipairs(pr_list) do
    if pr.headRefName == branch and pr.url then return pr.url end
  end
  return nil
end

local function get_base_branch_candidates()
  local output = vim.fn.system({ 'git', 'branch', '-a', '--format=%(refname:short)' })
  if vim.v.shell_error ~= 0 or not output or output == '' then return { 'main' } end

  local branch_set = {}
  for line in output:gmatch('[^\n]+') do
    branch_set[line:gsub('^origin/', '')] = true
  end

  local candidates = {}
  local preferred = { 'develop', 'main', 'master' }
  for _, name in ipairs(preferred) do
    if branch_set[name] then table.insert(candidates, name) end
  end

  if #candidates == 0 then table.insert(candidates, 'main') end
  return candidates
end

--- Parse the `owner/repo` slug from the origin remote (offline, no gh call).
---@return string|nil slug e.g. "JimmyTranDev/dotfiles"
local function get_repo_slug()
  local remote_url = vim.fn.system('git remote get-url origin 2>/dev/null'):gsub('%s+$', '')
  if vim.v.shell_error ~= 0 or remote_url == '' then return nil end

  local owner, repo = github_utils.parse_repo_url(remote_url)
  if not owner or not repo then return nil end

  return owner .. '/' .. repo
end

--- Build a GitHub compare URL (base...head) and copy it to the system clipboard.
---@param slug string owner/repo
---@param base string base branch (e.g. develop or main)
---@param head string head branch (current branch)
local function copy_compare_link(slug, base, head)
  local url = string.format('https://github.com/%s/compare/%s...%s', slug, base, head)
  vim.fn.setreg('+', url)
  vim.notify('Copied diff link: ' .. url, vim.log.levels.INFO)
end

function M.open_or_create_pull_request()
  local branch = git_utils.get_current_branch()
  if not branch or branch == '' then
    vim.notify('Could not determine current branch', vim.log.levels.ERROR)
    return
  end

  local pr_url = get_pr_for_branch(branch)
  if pr_url then
    file_utils.open(pr_url)
    vim.notify('Opened existing PR for branch: ' .. branch, vim.log.levels.INFO)
    return
  end

  local base_candidates = get_base_branch_candidates()
  local base = base_candidates[1]

  local result = vim.fn.system({ 'gh', 'pr', 'create', '--base', base, '--fill', '--web' })

  if vim.v.shell_error == 0 then
    vim.notify('PR creation opened in browser for branch: ' .. branch, vim.log.levels.INFO)
  else
    vim.notify('Failed to create PR: ' .. result, vim.log.levels.ERROR)
  end
end

function M.copy_pr_link()
  local branch = git_utils.get_current_branch()
  if not branch or branch == '' then
    vim.notify('Could not determine current branch', vim.log.levels.ERROR)
    return
  end

  local pr_url = get_pr_for_branch(branch)
  if not pr_url then
    vim.notify('No PR found for branch: ' .. branch, vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', pr_url)
  vim.notify('Copied PR link: ' .. pr_url, vim.log.levels.INFO)
end

--- Copy a GitHub compare link between the current branch and a base branch.
--- The base is auto-selected when only one of develop/main/master exists, and
--- prompts to choose when more than one is present.
function M.copy_diff_link()
  local branch = git_utils.get_current_branch()
  if not branch or branch == '' then
    vim.notify('Could not determine current branch', vim.log.levels.ERROR)
    return
  end

  local slug = get_repo_slug()
  if not slug then
    vim.notify('Could not determine GitHub repository from origin remote', vim.log.levels.ERROR)
    return
  end

  local candidates = get_base_branch_candidates()
  if #candidates == 1 then
    copy_compare_link(slug, candidates[1], branch)
    return
  end

  vim.ui.select(candidates, {
    prompt = 'Base branch to compare against:',
  }, function(base)
    if not base then return end
    copy_compare_link(slug, base, branch)
  end)
end

function M.rebase_choose_ours()
  local current_branch = git_utils.get_current_branch()
  if not current_branch or current_branch == '' then
    vim.notify('Could not determine current branch', vim.log.levels.ERROR)
    return
  end

  local branch_output = vim.fn.system({ 'git', 'branch', '-a', '--format=%(refname:short)' })
  if vim.v.shell_error ~= 0 or not branch_output or branch_output == '' then
    vim.notify('No other branches found', vim.log.levels.ERROR)
    return
  end

  local branches = {}
  local seen = {}
  for line in branch_output:gmatch('[^\n]+') do
    if line ~= '' and line ~= current_branch then
      local clean_branch = line:gsub('origin/', '')
      if not seen[clean_branch] then
        seen[clean_branch] = true
        table.insert(branches, clean_branch)
        if #branches >= 20 then break end
      end
    end
  end

  if #branches == 0 then
    vim.notify('No valid branches to rebase onto', vim.log.levels.ERROR)
    return
  end

  vim.ui.select(branches, {
    prompt = 'Select branch to rebase onto (will choose "ours" for all conflicts):',
    format_item = function(item) return item end,
  }, function(selected_branch)
    if not selected_branch then return end

    vim.ui.input({
      prompt = string.format('Rebase %s onto %s (choose ours for all conflicts)? Type "yes" to confirm: ', current_branch, selected_branch),
    }, function(confirmation)
      if confirmation ~= 'yes' then
        vim.notify('Rebase cancelled.')
        return
      end

      local cmd = string.format('git rebase -X ours %s', selected_branch)
      vim.cmd(string.format("TermExec5 cmd='%s'", cmd))

      vim.notify(string.format('Rebasing %s onto %s (choosing ours for conflicts)', current_branch, selected_branch))
    end)
  end)
end

function M.init_repo_and_push()
  local cwd = vim.fn.getcwd()
  local folder_name = vim.fn.fnamemodify(cwd, ':t')

  if folder_name == '' then
    vim.notify('Could not determine folder name', vim.log.levels.ERROR)
    return
  end

  local git_check = vim.fn.system('git rev-parse --is-inside-work-tree 2>/dev/null')
  if vim.v.shell_error == 0 and git_check:match('true') then
    vim.notify('Already a git repository', vim.log.levels.WARN)
    return
  end

  vim.ui.input({
    prompt = string.format('Create private repo "%s" and push? (y/n): ', folder_name),
  }, function(confirmation)
    if confirmation ~= 'y' then
      vim.notify('Cancelled.')
      return
    end

    local init_result = vim.fn.system('git init')
    if vim.v.shell_error ~= 0 then
      vim.notify('Failed to init git repo: ' .. init_result, vim.log.levels.ERROR)
      return
    end

    local add_result = vim.fn.system('git add .')
    if vim.v.shell_error ~= 0 then
      vim.notify('Failed to add files: ' .. add_result, vim.log.levels.ERROR)
      return
    end

    local commit_result = vim.fn.system('git commit -m "init: initial commit"')
    if vim.v.shell_error ~= 0 then
      vim.notify('Failed to create initial commit: ' .. commit_result, vim.log.levels.ERROR)
      return
    end

    local create_result = vim.fn.system(string.format('gh repo create %s --private --source=. --push', folder_name))
    if vim.v.shell_error ~= 0 then
      vim.notify('Failed to create GitHub repo: ' .. create_result, vim.log.levels.ERROR)
      return
    end

    vim.notify(string.format('Created private repo "%s" and pushed initial commit', folder_name), vim.log.levels.INFO)
  end)
end

function M.diff_vs(ref)
  local ok, snacks = pcall(require, 'snacks')
  if ok then snacks.picker.git_diff({ args = { ref } }) end
end

function M.show_commits_current_folder()
  local ok, snacks = pcall(require, 'snacks')
  if not ok then
    vim.notify('snacks.nvim is not available', vim.log.levels.ERROR)
    return
  end

  local dir = vim.fn.expand('%:p:h')
  if dir == '' then dir = vim.fn.getcwd() end

  local in_work_tree = vim.fn.system({ 'git', '-C', dir, 'rev-parse', '--is-inside-work-tree' })
  if vim.v.shell_error ~= 0 or not in_work_tree:match('true') then
    vim.notify('Not inside a git repository: ' .. dir, vim.log.levels.WARN)
    return
  end

  -- snacks resolves `cwd` to the git root before running, so a `.` pathspec
  -- would match the whole repo. Pass the absolute folder as the pathspec to
  -- restrict the log to commits that touch this folder.
  snacks.picker.git_log({
    cwd = dir,
    cmd_args = { '--', dir },
  })
end

function M.create_pr_from_branch()
  local branch = git_utils.get_current_branch()
  if not branch or branch == '' then
    vim.notify('Could not determine current branch', vim.log.levels.ERROR)
    return
  end

  local pr_url = get_pr_for_branch(branch)
  if pr_url then
    file_utils.open(pr_url)
    vim.notify('Opened existing PR for branch: ' .. branch, vim.log.levels.INFO)
    return
  end

  local jira_ticket = git_utils.extract_jira_ticket(branch)
  local description = branch:gsub('^[^/]+/', '')
  if jira_ticket ~= '' then description = description:gsub('^' .. jira_ticket:gsub('%-', '%%-') .. '[_%-]?', '') end
  description = description:gsub('[_%-]', ' ')

  local title = jira_ticket ~= '' and (jira_ticket .. ' ' .. description) or description

  local base_candidates = get_base_branch_candidates()
  local base = base_candidates[1]

  local result = vim.fn.system({ 'gh', 'pr', 'create', '--title', title, '--body', '', '--base', base, '--web' })

  if vim.v.shell_error == 0 then
    vim.notify('PR created for branch: ' .. branch, vim.log.levels.INFO)
  else
    vim.notify('Failed to create PR: ' .. result, vim.log.levels.ERROR)
  end
end

return M
