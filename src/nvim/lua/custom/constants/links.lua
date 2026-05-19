local M = {}

M.jira_ticket_url = vim.env.ORG_JIRA_TICKET_LINK or ''
local json_utils = require('custom.utils.json')
local expand = vim.fn.expand

local links = json_utils.parse_json_from_file(expand('$HOME/Programming/JimmyTranDev/secrets/links.json'))

M.project_name_to_route_object = links.work_technical or {}
M.project_names = {}
for project_name, _ in pairs(M.project_name_to_route_object) do
  table.insert(M.project_names, project_name)
end

M.useful_link = links.work_useful or {}
M.useful_link_names = {}
for key in pairs(M.useful_link) do
  table.insert(M.useful_link_names, key)
end

M.private_useful_link = links.private_useful or {}
M.private_useful_link_names = {}
for key in pairs(M.private_useful_link) do
  table.insert(M.private_useful_link_names, key)
end

return M
