-- Aggregates the split git action submodules into a single table so callers can
-- continue to `require('custom.actions.git')` unchanged. Each submodule returns
-- a table of `M.*` functions; they are merged here with no key collisions.
local M = {}

for _, name in ipairs({ 'commit', 'stash', 'remote' }) do
  for key, value in pairs(require('custom.actions.git.' .. name)) do
    M[key] = value
  end
end

return M
