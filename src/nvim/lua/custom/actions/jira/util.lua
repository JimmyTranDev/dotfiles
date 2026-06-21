local M = {}

M.CONFIG = {
  CACHE_DIR = vim.fn.stdpath('data'),
  DEFAULT_PROJECT = 'BW',
  LIMIT = 50,
  AUTO_TRANSITION = true,
  TRANSITION_STATUSES = { 'In Progress Concept', 'Done Concept', 'Prioritised Issues Development' },
  -- Sentinel marking where the "Done Concept only" path stops within TRANSITION_STATUSES.
  -- Must exist in the chain above; the slice fails closed if it does not.
  DONE_CONCEPT_STATUS = 'Done Concept',
}

function M.get_current_user_email()
  local email = os.getenv('ORG_EMAIL')
  return email and email:match('^%s*(.-)%s*$')
end

function M.parse_csv_line(line)
  local fields = {}
  local field = ''
  local in_quotes = false
  local i = 1

  while i <= #line do
    local char = line:sub(i, i)
    if char == '"' then
      in_quotes = not in_quotes
    elseif char == ',' and not in_quotes then
      table.insert(fields, field:match('^%s*(.-)%s*$'))
      field = ''
    else
      field = field .. char
    end
    i = i + 1
  end

  table.insert(fields, field:match('^%s*(.-)%s*$'))
  return fields
end

return M
