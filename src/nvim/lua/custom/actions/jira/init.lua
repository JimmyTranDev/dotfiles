-- Aggregates the split jira action submodules into a single table so callers can
-- continue to `require('custom.actions.jira')` unchanged. Each submodule returns
-- a table of `M.*` functions; they are merged here with no key collisions.
local M = {}

for _, name in ipairs({ 'create', 'report', 'branch' }) do
  for key, value in pairs(require('custom.actions.jira.' .. name)) do
    M[key] = value
  end
end

return M
