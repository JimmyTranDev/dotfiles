local M = {}

local file_utils = require('custom.utils.files')
local string_utils = require('custom.utils.string')
local git_utils = require('custom.utils.git')

local ui_utils = require('custom.utils.ui')

local NOTES_PATH = vim.fn.expand('~/Programming/JimmyTranDev/notes/people')
local SENTENCES_PATH = vim.fn.expand('~/Programming/JimmyTranDev/notes/notes')
local TASKS_FILE = vim.fn.expand('~/Programming/JimmyTranDev/notes/tasks.md')

local function get_md_files(dir)
  local files = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then return files end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if type == 'file' and name:match('%.md$') then table.insert(files, name) end
  end

  table.sort(files)
  return files
end

local function get_notes_files() return get_md_files(NOTES_PATH) end

function M.add_notes_entry()
  local files = get_notes_files()
  if #files == 0 then
    vim.notify('No files found in notes/people', vim.log.levels.WARN)
    return
  end

  local display_names = {}
  for _, file in ipairs(files) do
    table.insert(display_names, file:gsub('%.md$', ''))
  end

  vim.ui.select(display_names, { prompt = 'Select note: ' }, function(choice, idx)
    if not choice then return end

    vim.ui.input({ prompt = 'Entry for ' .. choice .. ': ' }, function(input)
      if not input or input == '' then return end

      input = string_utils.capitalize_first_char(input)

      local filepath = NOTES_PATH .. '/' .. files[idx]
      local lines = file_utils.read_lines(filepath)
      table.insert(lines, '🩷 ' .. input .. '  ')

      if file_utils.write_lines(filepath, lines) then
        vim.notify('Entry added to ' .. choice, vim.log.levels.INFO)
        git_utils.sync_notes_repo()
      else
        vim.notify('Failed to write entry', vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.add_sentence()
  local files = get_md_files(SENTENCES_PATH)
  local options = { { name = '+ Create new note', is_new = true } }
  for _, file in ipairs(files) do
    table.insert(options, { name = file:gsub('%.md$', ''), filename = file })
  end

  ui_utils.safe_select(options, {
    prompt = 'Select note:',
    format_item = function(item) return item.name end,
  }, function(selected)
    if selected.is_new then
      vim.ui.input({ prompt = 'New note name: ' }, function(name)
        if not name or name == '' then return end
        local filename = name:gsub('%s+', '-'):lower() .. '.md'
        local filepath = SENTENCES_PATH .. '/' .. filename
        vim.ui.input({ prompt = 'Sentence: ' }, function(sentence)
          if not sentence or sentence == '' then return end
          sentence = string_utils.capitalize_first_char(sentence)
          local lines = { '# ' .. name, '', sentence .. '  ' }
          if file_utils.write_lines(filepath, lines) then
            vim.notify('Note created: ' .. filename, vim.log.levels.INFO)
            git_utils.sync_notes_repo()
          else
            vim.notify('Failed to create note', vim.log.levels.ERROR)
          end
        end)
      end)
    else
      local filepath = SENTENCES_PATH .. '/' .. selected.filename
      vim.ui.input({ prompt = 'Sentence for ' .. selected.name .. ': ' }, function(sentence)
        if not sentence or sentence == '' then return end
        sentence = string_utils.capitalize_first_char(sentence)
        local lines = file_utils.read_lines(filepath)
        table.insert(lines, sentence .. '  ')
        if file_utils.write_lines(filepath, lines) then
          vim.notify('Sentence added to ' .. selected.name, vim.log.levels.INFO)
          git_utils.sync_notes_repo()
        else
          vim.notify('Failed to write sentence', vim.log.levels.ERROR)
        end
      end)
    end
  end)
end

function M.save_task()
  local TASK_INPUT_OPTIONS = {
    { name = 'Enter title' },
    { name = 'Enter description' },
  }

  ui_utils.safe_select(TASK_INPUT_OPTIONS, {
    prompt = 'What do you want to enter?',
    format_item = function(item) return item.name end,
  }, function(selected)
    if selected.name == 'Enter description' then
      ui_utils.multiline_input({ title = 'Task description' }, function(description)
        if not description or description == '' then return end
        local timestamp = os.date('%Y-%m-%d %H:%M')
        local entry = '\n## Task — ' .. timestamp .. '\n\n' .. description .. '\n'
        local lines = file_utils.read_lines(TASKS_FILE)
        if #lines == 0 then
          lines = { '# Tasks', '' }
        end
        table.insert(lines, entry)
        if file_utils.write_lines(TASKS_FILE, lines) then
          vim.notify('Task saved to notes', vim.log.levels.INFO)
          git_utils.sync_notes_repo()
        else
          vim.notify('Failed to save task', vim.log.levels.ERROR)
        end
      end)
    else
      vim.ui.input({ prompt = 'Task title: ' }, function(title)
        if not title or title == '' then return end
        title = string_utils.capitalize_first_char(title)

        ui_utils.multiline_input({ title = 'Task description (optional)' }, function(description)
          local timestamp = os.date('%Y-%m-%d %H:%M')
          local entry = '\n## ' .. title .. ' — ' .. timestamp .. '\n'
          if description and description ~= '' then
            entry = entry .. '\n' .. description .. '\n'
          end
          local lines = file_utils.read_lines(TASKS_FILE)
          if #lines == 0 then
            lines = { '# Tasks', '' }
          end
          table.insert(lines, entry)
          if file_utils.write_lines(TASKS_FILE, lines) then
            vim.notify('Task saved to notes', vim.log.levels.INFO)
            git_utils.sync_notes_repo()
          else
            vim.notify('Failed to save task', vim.log.levels.ERROR)
          end
        end)
      end)
    end
  end)
end

local NOTE_TYPE_OPTIONS = {
  { name = 'Journal entry', action = 'journal' },
  { name = 'Person note', action = 'person' },
  { name = 'Topic note', action = 'sentence' },
  { name = 'Task', action = 'task' },
}

function M.quick_note()
  local journal_actions = require('custom.actions.journal')

  vim.ui.select(NOTE_TYPE_OPTIONS, {
    prompt = 'Quick note:',
    format_item = function(item) return item.name end,
  }, function(selected)
    if not selected then return end

    if selected.action == 'journal' then
      journal_actions.add_journal_entry()
    elseif selected.action == 'person' then
      M.add_notes_entry()
    elseif selected.action == 'sentence' then
      M.add_sentence()
    elseif selected.action == 'task' then
      M.save_task()
    end
  end)
end

return M
