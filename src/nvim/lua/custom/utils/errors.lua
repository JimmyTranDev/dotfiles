local M = {}

function M.get_diagnostic_texts_under_cursor()
  local bufnr = vim.api.nvim_get_current_buf()
  local line = vim.api.nvim_win_get_cursor(0)[1] - 1 -- 0-based line number
  local col = vim.api.nvim_win_get_cursor(0)[2] -- 0-based column number

  local diagnostics = vim.diagnostic.get(bufnr, { lnum = line })

  local relevant_diagnostics = {}
  for _, diag in ipairs(diagnostics) do
    if col >= diag.col and col <= (diag.end_col or diag.col) then table.insert(relevant_diagnostics, diag) end
  end

  if #relevant_diagnostics == 0 then return 'No diagnostics found under cursor' end

  local result = {}
  for i, diag in ipairs(relevant_diagnostics) do
    local message = string.format('%d: %s (%s)', i, diag.message, vim.diagnostic.severity[diag.severity] or 'Unknown')
    table.insert(result, message)
  end

  return table.concat(result, '\n')
end

return M
