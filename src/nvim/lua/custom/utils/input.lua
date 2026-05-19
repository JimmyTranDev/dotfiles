local M = {}

function M.get_input(prompt, callback, default_text)
  vim.ui.input({ prompt = prompt, default = default_text or '' }, function(input)
    if not input or input == '' then
      callback(nil)
      return
    end
    callback(input)
  end)
end

function M.get_selected_text(clean)
  local old_reg = vim.fn.getreg('"')
  vim.cmd('normal! ""y')
  local selected = vim.fn.getreg('"')
  vim.fn.setreg('"', old_reg)
  if clean then return selected:gsub('"', ''):gsub(':', '') end
  return selected
end

return M
