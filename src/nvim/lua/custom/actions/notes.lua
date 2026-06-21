local M = {}

local file_utils = require('custom.utils.files')
local string_utils = require('custom.utils.string')
local grammar_utils = require('custom.utils.grammar')
local git_utils = require('custom.utils.git')
local usage_cache = require('custom.utils.usage_cache')

local ui_utils = require('custom.utils.ui')

local SENTENCES_PATH = vim.fn.expand('~/Programming/JimmyTranDev/notes/notes')

local NOTE_CATEGORIES_NS = 'note_categories'
local MAX_RECENT_CATEGORIES = 10

local function add_recent_category(name) usage_cache.record(NOTE_CATEGORIES_NS, name) end

local function build_category_priority_map()
  local map = {}
  for index, name in ipairs(usage_cache.recent(NOTE_CATEGORIES_NS, MAX_RECENT_CATEGORIES)) do
    map[name] = index - 1
  end
  return map
end

local function get_md_files(dir)
  local files = {}
  for _, f in ipairs(file_utils.scan(dir, { type = 'file', hidden = true })) do
    if f.name:match('%.md$') then table.insert(files, f.name) end
  end
  table.sort(files)
  return files
end

local function get_subdirs(dir)
  local dirs = {}
  for _, d in ipairs(file_utils.scan(dir, { type = 'directory', hidden = true })) do
    table.insert(dirs, d.name)
  end
  table.sort(dirs)
  return dirs
end

-- Auto-discover a category (subfolder of notes/notes), then let the user pick an
-- existing document or create a new one. Resolves the chosen filepath and a
-- friendly display name, then hands off to `callback(filepath, display_name)`.
local function select_category_then_doc(action_label, callback)
  local categories = get_subdirs(SENTENCES_PATH)
  if #categories == 0 then
    vim.notify('No categories found in notes/notes', vim.log.levels.WARN)
    return
  end

  local category_options = {}
  for _, dir in ipairs(categories) do
    if dir ~= 'journal' then table.insert(category_options, { name = dir, dir = dir }) end
  end

  local priority_map = build_category_priority_map()
  table.sort(category_options, function(a, b)
    local a_priority = priority_map[a.dir] or 999
    local b_priority = priority_map[b.dir] or 999
    if a_priority ~= b_priority then return a_priority < b_priority end
    return a.name < b.name
  end)

  ui_utils.safe_select(category_options, {
    prompt = action_label .. ' — select category:',
    format_item = function(item) return item.name end,
  }, function(category)
    add_recent_category(category.dir)
    local category_path = SENTENCES_PATH .. '/' .. category.dir
    local files = get_md_files(category_path)

    local doc_options = { { name = '+ Create new note', is_new = true } }
    for _, file in ipairs(files) do
      table.insert(doc_options, { name = file:gsub('%.md$', ''), filename = file })
    end

    ui_utils.safe_select(doc_options, {
      prompt = action_label .. ' — select note:',
      format_item = function(item) return item.name end,
    }, function(selected)
      if selected.is_new then
        vim.ui.input({ prompt = 'New note name: ' }, function(name)
          if not name or name == '' then return end
          local filename = name:gsub('%s+', '-'):lower() .. '.md'
          local filepath = category_path .. '/' .. filename
          file_utils.ensure_directory_exists(filepath)
          if vim.fn.filereadable(filepath) == 0 then file_utils.write_lines(filepath, { '# ' .. name, '' }) end
          callback(filepath, name)
        end)
      else
        callback(category_path .. '/' .. selected.filename, selected.name)
      end
    end)
  end)
end

-- Continuously prompt for bullet entries (like the journal flow) and append
-- each one to the selected categorized note until an empty line is submitted.
function M.add_categorized_note()
  select_category_then_doc('Add note', function(filepath, name)
    local function prompt_entry()
      vim.ui.input({ prompt = 'Note for ' .. name .. ': ' }, function(input)
        if not input or input == '' then return end
        input = string_utils.capitalize_first_char(grammar_utils.fix(input))
        local lines = file_utils.read_lines(filepath)
        table.insert(lines, '- ' .. input)
        if file_utils.write_lines(filepath, lines) then
          git_utils.sync_notes_repo()
          prompt_entry()
        else
          vim.notify('Failed to write note', vim.log.levels.ERROR)
        end
      end)
    end

    prompt_entry()
  end)
end

local HEADING_SIZES = {
  { name = 'H1  #', level = 1 },
  { name = 'H2  ##', level = 2 },
  { name = 'H3  ###', level = 3 },
  { name = 'H4  ####', level = 4 },
  { name = 'H5  #####', level = 5 },
  { name = 'H6  ######', level = 6 },
}

-- Add a markdown heading to a selected categorized note, choosing the heading
-- level (H1-H6) before entering the heading text.
function M.add_categorized_heading()
  select_category_then_doc('Add heading', function(filepath, name)
    ui_utils.safe_select(HEADING_SIZES, {
      prompt = 'Heading size:',
      format_item = function(item) return item.name end,
    }, function(size)
      vim.ui.input({ prompt = 'Heading text: ' }, function(text)
        if not text or text == '' then return end
        text = string_utils.capitalize_first_char(grammar_utils.fix(text))
        local lines = file_utils.read_lines(filepath)
        if #lines > 0 and lines[#lines] ~= '' then table.insert(lines, '') end
        table.insert(lines, string.rep('#', size.level) .. ' ' .. text)
        table.insert(lines, '')
        if file_utils.write_lines(filepath, lines) then
          vim.notify('Heading added to ' .. name, vim.log.levels.INFO)
          git_utils.sync_notes_repo()
        else
          vim.notify('Failed to write heading', vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

return M
