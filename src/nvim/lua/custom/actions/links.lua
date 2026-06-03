local link_utils = require('custom.utils.links')
local git_utils = require('custom.utils.git')
local link_constants = require('custom.constants.links')
local language_utils = require('custom.utils.language')
local file_utils = require('custom.utils.files')
local github_utils = require('custom.utils.github')
local ui_utils = require('custom.utils.ui')
local url_utils = require('custom.utils.url')
local json_utils = require('custom.utils.json')

local M = {}

local LINK_USAGE_FILE = vim.fn.stdpath('data') .. '/link_usage.json'

local function load_link_usage()
  return json_utils.parse_json_from_file(LINK_USAGE_FILE)
end

local function save_link_usage(usage)
  json_utils.write_json_to_file(LINK_USAGE_FILE, usage)
end

local function record_link_usage(link_name)
  local usage = load_link_usage()
  usage[link_name] = os.time()
  save_link_usage(usage)
end

local function sort_by_recent_use(link_names)
  local usage = load_link_usage()
  table.sort(link_names, function(a, b)
    local ta = usage[a] or 0
    local tb = usage[b] or 0
    if ta ~= tb then
      return ta > tb
    end
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

function M.open_current_github_repo()
  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.url then
    vim.notify('Failed to get repository info. Make sure you are in a git repository and gh CLI is authenticated.', vim.log.levels.ERROR)
    return
  end
  open_url(repo_info.url .. '/pulls', 'GitHub pull requests')
end

function M.open_current_github_prs()
  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.url then
    vim.notify('Failed to get repository info. Make sure you are in a git repository and gh CLI is authenticated.', vim.log.levels.ERROR)
    return
  end
  open_url(repo_info.url .. '/pulls?q=is:pr+is:open+author:@me', 'My GitHub pull requests')
end

function M.open_dev_server() language_utils.open_server_url('dev') end

function M.open_useful_link()
  local link_names = vim.deepcopy(link_constants.useful_link_names)
  local useful_links = link_constants.useful_link

  if not link_names or #link_names == 0 then
    vim.notify('No useful links configured', vim.log.levels.WARN)
    return
  end

  sort_by_recent_use(link_names)

  ui_utils.safe_select(link_names, { prompt = 'Select link to open:' }, function(link_name)
    local url = useful_links[link_name]
    if url then
      record_link_usage(link_name)
      open_url(url, link_name)
    else
      vim.notify('Link not found: ' .. link_name, vim.log.levels.ERROR)
    end
  end)
end

function M.open_private_useful_link()
  local link_names = vim.deepcopy(link_constants.private_useful_link_names)
  local private_useful_links = link_constants.private_useful_link

  if not link_names or #link_names == 0 then
    vim.notify('No private useful links configured', vim.log.levels.WARN)
    return
  end

  sort_by_recent_use(link_names)

  ui_utils.safe_select(link_names, { prompt = 'Select private link to open:' }, function(link_name)
    local url = private_useful_links[link_name]
    if url then
      record_link_usage(link_name)
      open_url(url, link_name)
    else
      vim.notify('Link not found: ' .. link_name, vim.log.levels.ERROR)
    end
  end)
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

    local route_names = {}
    for key in pairs(routes) do
      table.insert(route_names, key)
    end
    table.sort(route_names)

    ui_utils.safe_select(route_names, { prompt = 'Select link type:' }, function(route_name)
      local url = routes[route_name]
      if url then
        record_link_usage(project_name .. ':' .. route_name)
        open_url(url, project_name .. ' (' .. route_name .. ')')
      end
    end)
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

  local route_names = {}
  for key in pairs(routes) do
    table.insert(route_names, key)
  end
  table.sort(route_names)

  ui_utils.safe_select(route_names, { prompt = 'Select link type:' }, function(route_name)
    local url = routes[route_name]
    if url then
      record_link_usage(repo_name .. ':' .. route_name)
      open_url(url, repo_name .. ' (' .. route_name .. ')')
    end
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
