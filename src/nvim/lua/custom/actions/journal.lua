local M = {}

local file_utils = require('custom.utils.files')
local string_utils = require('custom.utils.string')
local git_utils = require('custom.utils.git')

local JOURNAL_BASE_PATH = vim.fn.expand('~/Programming/JimmyTranDev/notes/journal')

local function format_day_header()
  local weekday = os.date('%A')
  local day = tonumber(os.date('%d'))
  local month_name = os.date('%B')
  local year = os.date('%Y')
  return string.format('%s, %d %s %s', weekday, day, month_name, year)
end

local function get_journal_path()
  local year = os.date('%Y')
  local month = os.date('%m')
  return string.format('%s/%s/%s.md', JOURNAL_BASE_PATH, year, month)
end

local function parse_existing_days(lines)
  local days = {}
  for i, line in ipairs(lines) do
    local day = line:match('^## %a+, (%d+) %a+ %d%d%d%d$')
    if day then days[tonumber(day)] = i end
  end
  return days
end

local function find_insertion_point(lines, today, existing_days)
  for day = today - 1, 1, -1 do
    if existing_days[day] then
      local next_header_line = nil
      for i = existing_days[day] + 1, #lines do
        if lines[i]:match('^## %a+, %d+ %a+ %d%d%d%d$') then
          next_header_line = i
          break
        end
      end
      return next_header_line or (#lines + 1), day
    end
  end

  for day = today + 1, 31 do
    if existing_days[day] then return existing_days[day], nil end
  end

  return #lines + 1, nil
end

local function find_entry_insert_line(lines, today, existing_days)
  if not existing_days[today] then return nil end

  local header_line = existing_days[today]
  for i = header_line + 1, #lines do
    if lines[i]:match('^## %a+, %d+ %a+ %d%d%d%d$') then
      local insert_at = i
      while insert_at > header_line + 1 and lines[insert_at - 1] == '' do
        insert_at = insert_at - 1
      end
      return insert_at
    end
  end
  return #lines + 1
end

local function ensure_today_header(filepath)
  file_utils.ensure_directory_exists(filepath)
  local today = tonumber(os.date('%d'))
  local lines = file_utils.read_lines(filepath)
  local existing_days = parse_existing_days(lines)

  if not existing_days[today] then
    local header = format_day_header()
    local insert_line, after_day = find_insertion_point(lines, today, existing_days)

    if after_day then
      table.insert(lines, insert_line, '')
      table.insert(lines, insert_line + 1, '## ' .. header)
    elseif insert_line <= #lines then
      table.insert(lines, insert_line, '## ' .. header)
      table.insert(lines, insert_line + 1, '')
    else
      if #lines > 0 then table.insert(lines, '') end
      table.insert(lines, '## ' .. header)
    end

    file_utils.write_lines(filepath, lines)
    existing_days = parse_existing_days(lines)
  end

  return lines, existing_days, today
end

function M.add_journal_entry()
  vim.ui.input({ prompt = 'Journal entry: ' }, function(input)
    if not input or input == '' then return end

    input = string_utils.capitalize_first_char(input)

    local filepath = get_journal_path()
    local lines, existing_days, today = ensure_today_header(filepath)

    local entry_line = find_entry_insert_line(lines, today, existing_days)
    if entry_line then table.insert(lines, entry_line, '- ' .. input) end

    if file_utils.write_lines(filepath, lines) then
      vim.notify('Journal entry added', vim.log.levels.INFO)
      git_utils.sync_notes_repo()
    else
      vim.notify('Failed to write journal entry', vim.log.levels.ERROR)
    end
  end)
end

function M.open_journal()
  local filepath = get_journal_path()
  local _, existing_days, today = ensure_today_header(filepath)

  vim.cmd('edit ' .. vim.fn.fnameescape(filepath))

  if existing_days[today] then
    vim.api.nvim_win_set_cursor(0, { existing_days[today] + 1, 0 })
    vim.cmd('normal! zz')
  end
end

return M
