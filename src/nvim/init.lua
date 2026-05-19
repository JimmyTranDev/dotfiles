require('core.lazy')

local modules = {
  'core.options',
  'core.plugins',
  'core.commands',
  'core.keymaps',
}

for _, mod in ipairs(modules) do
  local ok, err = pcall(require, mod)
  if not ok then vim.notify('Failed to load ' .. mod .. ': ' .. err, vim.log.levels.ERROR) end
end
