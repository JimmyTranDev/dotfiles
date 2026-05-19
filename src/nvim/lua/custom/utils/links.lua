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

return M
