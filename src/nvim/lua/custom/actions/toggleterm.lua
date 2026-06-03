local M = {}

function M.create_kill_toggle_term(index)
  return function()
    local term = require('toggleterm.terminal').get_all()[index]
    if term then term:shutdown() end
  end
end

function M.kill_all_toggle_term()
  for _, term in pairs(require('toggleterm.terminal').get_all()) do
    term:shutdown()
  end
end

function M.get_next_free_terminal(start_id)
  local terminals = require('toggleterm.terminal')
  local id = start_id or 1
  for _ = 1, 20 do
    local term = terminals.get(id)
    if not term or not term:is_open() then
      return id
    end
    id = id + 1
  end
  return id
end

return M
