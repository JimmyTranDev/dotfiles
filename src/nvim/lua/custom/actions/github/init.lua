-- Aggregates the split github action submodules into a single table so callers
-- can continue to `require('custom.actions.github')` unchanged. Each submodule
-- returns a table of `M.*` functions; they are merged here with no key
-- collisions. The shared `util` module is intentionally internal (not merged).
local M = {}

for _, name in ipairs({ 'pr', 'issues', 'team', 'review', 'notifications', 'clone', 'links' }) do
  for key, value in pairs(require('custom.actions.github.' .. name)) do
    M[key] = value
  end
end

return M
