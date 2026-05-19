local errors_utils = require('custom.utils.errors')

local M = {}

function M.copy_diagnostic_under_cursor()
  local diagnostic_text = errors_utils.get_diagnostic_texts_under_cursor()

  if diagnostic_text == 'No diagnostics found under cursor' then
    vim.notify(diagnostic_text, vim.log.levels.WARN)
    return
  end

  vim.fn.setreg('+', diagnostic_text)
  vim.notify('Copied diagnostic to clipboard', vim.log.levels.INFO)
end

return M
