local M = {}

M.CONFIG = {
  CACHE_DIR = vim.fn.stdpath('data'),
  DEFAULT_PROJECT = 'BW',
  LIMIT = 50,
  AUTO_TRANSITION = true,
  TRANSITION_STATUSES = { 'In Progress Concept', 'Done Concept', 'Prioritised Issues Development' },
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

--- Pure: slice the transition chain from the start up to and INCLUDING `target`.
--- Returns a new list; empty when `target` is absent, so an unknown selection
--- fails closed instead of silently running the entire chain.
function M.slice_transition_chain(statuses, target)
  local subset = {}
  for _, status in ipairs(statuses) do
    table.insert(subset, status)
    if status == target then return subset end
  end
  return {}
end

return M
