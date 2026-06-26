local link_utils = require('custom.utils.links')
local git_utils = require('custom.utils.git')
local link_constants = require('custom.constants.links')
local language_utils = require('custom.utils.language')
local file_utils = require('custom.utils.files')
local github_utils = require('custom.utils.github')
local ui_utils = require('custom.utils.ui')
local url_utils = require('custom.utils.url')
local usage_cache = require('custom.utils.usage_cache')

local M = {}

local LINK_USAGE_NS = 'links'

local function record_link_usage(link_name) usage_cache.record(LINK_USAGE_NS, link_name) end

local function sort_by_recent_use(link_names)
  table.sort(link_names, function(a, b)
    local ta = usage_cache.get_last_used(LINK_USAGE_NS, a)
    local tb = usage_cache.get_last_used(LINK_USAGE_NS, b)
    if ta ~= tb then return ta > tb end
    return a < b
  end)
  return link_names
end

local function open_url(url, description)
  if not url or url == '' then
    vim.notify('Invalid URL', vim.log.levels.ERROR)
    return
  end
  file_utils.open(url)
  if description then vim.notify('Opened: ' .. description, vim.log.levels.INFO) end
end

local function open_repo_path(suffix, description)
  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.url then
    vim.notify('Failed to get repository info. Make sure you are in a git repository and gh CLI is authenticated.', vim.log.levels.ERROR)
    return
  end
  open_url(repo_info.url .. suffix, description)
end

function M.open_current_github_repo() open_repo_path('/pulls', 'GitHub pull requests') end

function M.open_current_github_prs() open_repo_path('/pulls?q=is:pr+is:open+author:@me', 'My GitHub pull requests') end

function M.open_dev_server() language_utils.open_server_url('dev') end

local function select_link(opts)
  local names = vim.deepcopy(opts.names)
  if not names or #names == 0 then
    vim.notify(opts.empty_msg, vim.log.levels.WARN)
    return
  end

  sort_by_recent_use(names)

  ui_utils.safe_select(names, { prompt = opts.prompt }, function(link_name)
    local url = opts.links[link_name]
    if url then
      record_link_usage(link_name)
      open_url(url, link_name)
    else
      vim.notify('Link not found: ' .. link_name, vim.log.levels.ERROR)
    end
  end)
end

function M.open_useful_link()
  select_link({
    names = link_constants.useful_link_names,
    links = link_constants.useful_link,
    empty_msg = 'No useful links configured',
    prompt = 'Select link to open:',
  })
end

function M.open_private_useful_link()
  select_link({
    names = link_constants.private_useful_link_names,
    links = link_constants.private_useful_link,
    empty_msg = 'No private useful links configured',
    prompt = 'Select private link to open:',
  })
end

function M.open_jira_ticket()
  local branch_name = git_utils.get_current_branch()
  if not branch_name or branch_name == '' then
    vim.notify('Not in a git repository or no branch found', vim.log.levels.WARN)
    return
  end

  local jira_ticket = git_utils.extract_jira_ticket(branch_name)
  if not jira_ticket or jira_ticket == '' then
    vim.notify('No JIRA ticket found in branch name: ' .. branch_name, vim.log.levels.WARN)
    return
  end

  local jira_link = link_utils.get_jira_link_with_ticket(jira_ticket)
  if jira_link then
    open_url(jira_link, 'JIRA ticket: ' .. jira_ticket)
  else
    vim.notify('Could not generate JIRA link for: ' .. jira_ticket, vim.log.levels.ERROR)
  end
end

function M.open_npm_url()
  local old_reg = vim.fn.getreg('"')
  vim.cmd('normal! yiW')
  local package_name = vim.fn.getreg('"')
  vim.fn.setreg('"', old_reg)

  if not package_name or package_name == '' then
    vim.notify('No package name under cursor', vim.log.levels.WARN)
    return
  end

  package_name = package_name:gsub('["\':,]', '')
  local npm_url = link_utils.get_npm_url(package_name)
  if npm_url then
    open_url(npm_url, 'NPM package: ' .. package_name)
  else
    vim.notify('Could not generate NPM URL for: ' .. package_name, vim.log.levels.ERROR)
  end
end

function M.search_google()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' or mode == '\22' then
    vim.cmd('normal! "zy')
    local text = vim.fn.getreg('z')
    if text and text ~= '' then
      local encoded = url_utils.urlencode(text)
      file_utils.open('https://www.google.com/search?q=' .. encoded)
      return
    end
  end

  vim.ui.input({ prompt = 'Google: ' }, function(input)
    if not input or input == '' then return end
    local encoded = url_utils.urlencode(input)
    file_utils.open('https://www.google.com/search?q=' .. encoded)
  end)
end

local function select_route(name, routes)
  local route_names = {}
  for key in pairs(routes) do
    table.insert(route_names, key)
  end
  table.sort(route_names)

  ui_utils.safe_select(route_names, { prompt = 'Select link type:' }, function(route_name)
    local url = routes[route_name]
    if url then
      record_link_usage(name .. ':' .. route_name)
      open_url(url, name .. ' (' .. route_name .. ')')
    end
  end)
end

function M.open_technical_link()
  local project_names = vim.deepcopy(link_constants.project_names)
  if #project_names == 0 then
    vim.notify('No technical links configured', vim.log.levels.WARN)
    return
  end

  table.sort(project_names)

  ui_utils.safe_select(project_names, { prompt = 'Select project:' }, function(project_name)
    local routes = link_constants.project_name_to_route_object[project_name]
    if not routes then
      vim.notify('No routes found for: ' .. project_name, vim.log.levels.WARN)
      return
    end
    select_route(project_name, routes)
  end)
end

function M.open_technical_link_current_repo()
  local repo_name = github_utils.get_repo_name()
  if not repo_name or repo_name == '' then
    vim.notify('Not in a git repository', vim.log.levels.WARN)
    return
  end

  local routes = link_constants.project_name_to_route_object[repo_name]
  if not routes then
    vim.notify('No technical links found for: ' .. repo_name, vim.log.levels.WARN)
    return
  end

  select_route(repo_name, routes)
end

function M.open_fms_link()
  local base = link_constants.fms_admin_base
  if not base or base == '' then
    vim.notify('FMS admin base URL not set. Add "fms_admin_base" to secrets/links.json (run: storage-init).', vim.log.levels.WARN)
    return
  end

  local repo_name = github_utils.get_repo_name()
  if not repo_name or repo_name == '' then repo_name = vim.fn.fnamemodify(vim.fn.getcwd(), ':t') end

  local default_slug = link_utils.to_fms_slug(repo_name)

  vim.ui.input({ prompt = 'FMS project: ', default = default_slug }, function(input)
    if not input then return end
    input = vim.trim(input)
    if input == '' then return end

    local url = link_utils.get_fms_admin_url(base, input)
    if not url then
      vim.notify('Could not build FMS URL for: ' .. input, vim.log.levels.ERROR)
      return
    end

    record_link_usage('fms:' .. input)
    open_url(url, 'FMS admin: ' .. input)
  end)
end

function M.open_firefox_container()
  vim.ui.input({ prompt = 'Container name: ' }, function(container)
    if not container or container == '' then return end

    vim.ui.input({ prompt = 'URL: ' }, function(url)
      if not url or url == '' then return end

      local encoded_url = url_utils.urlencode(url)
      local container_url = string.format('ext+container:name=%s&url=%s', url_utils.urlencode(container), encoded_url)
      vim.fn.system({ 'open', '-a', 'Firefox', container_url })
      vim.notify(string.format('Opened in Firefox [%s]: %s', container, url), vim.log.levels.INFO)
    end)
  end)
end

return M
