local link_constants = require('custom.constants.links')
local url_utils = require('custom.utils.url')

local M = {}

function M.get_npm_url(query) return 'https://www.npmjs.com/package/' .. url_utils.urlencode(query) end

function M.get_jira_link_with_ticket(ticket)
  if not link_constants.jira_ticket_url or link_constants.jira_ticket_url == '' then
    vim.notify('ORG_JIRA_TICKET_LINK not set', vim.log.levels.ERROR)
    return nil
  end
  return link_constants.jira_ticket_url .. ticket
end

-- Repo-name suffixes dropped before building an FMS slug (bank-onboarding-web -> bank-onboarding).
local FMS_SLUG_STRIP_SUFFIXES = { '%-web$', '%-app$' }

--- Derive the FMS project slug from a repo name: drop a trailing -web/-app suffix, then
--- camelCase the hyphen/underscore-separated parts (bank-onboarding-web -> bankOnboarding).
---@param repo_name string|nil
---@return string slug '' when repo_name is empty or invalid
function M.to_fms_slug(repo_name)
  if type(repo_name) ~= 'string' or repo_name == '' then return '' end

  local name = repo_name
  for _, pattern in ipairs(FMS_SLUG_STRIP_SUFFIXES) do
    name = name:gsub(pattern, '')
  end

  local parts = {}
  for part in name:gmatch('[^-_]+') do
    table.insert(parts, part)
  end
  if #parts == 0 then return '' end

  local slug = parts[1]:sub(1, 1):lower() .. parts[1]:sub(2)
  for i = 2, #parts do
    slug = slug .. parts[i]:sub(1, 1):upper() .. parts[i]:sub(2)
  end
  return slug
end

--- Join an FMS admin base URL and a project slug into a trailing-slashed URL.
---@param base string|nil FMS admin base (e.g. https://host/fms-admin/)
---@param slug string|nil project slug (e.g. bankOnboarding)
---@return string|nil url nil when base or slug is empty
function M.get_fms_admin_url(base, slug)
  if not base or base == '' then return nil end
  if not slug or slug == '' then return nil end
  local normalized_base = base:gsub('/+$', '')
  local normalized_slug = slug:gsub('^/+', ''):gsub('/+$', '')
  if normalized_slug == '' then return nil end
  return normalized_base .. '/' .. normalized_slug .. '/'
end

return M
