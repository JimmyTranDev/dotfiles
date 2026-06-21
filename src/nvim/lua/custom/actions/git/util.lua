local M = {}

function M.shell_escape_message(msg) return msg:gsub('[$`"\\!]', '\\%0') end

return M
