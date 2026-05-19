local M = {}

local function is_test_file(filepath)
  if filepath:match('%.test%.') then
    return true
  end
  if filepath:match('%.spec%.') then
    return true
  end
  if filepath:match('__tests__/') then
    return true
  end
  return false
end

local function is_import_parent(node)
  local parent = node:parent()
  while parent do
    local ptype = parent:type()
    if ptype == 'import_statement' or ptype == 'import_source' then
      return true
    end
    parent = parent:parent()
  end
  return false
end

local function collect_texts_from_file(filepath)
  local results = {}

  local lines = vim.fn.readfile(filepath)
  if not lines or #lines == 0 then
    return results
  end

  if #lines > 10000 then
    return results
  end

  local source = table.concat(lines, '\n')

  local lang = nil
  if filepath:match('%.tsx$') then
    lang = 'tsx'
  elseif filepath:match('%.ts$') then
    lang = 'typescript'
  elseif filepath:match('%.jsx$') then
    lang = 'tsx'
  elseif filepath:match('%.js$') then
    lang = 'javascript'
  end

  if not lang then
    return results
  end

  local ok, parser = pcall(vim.treesitter.get_string_parser, source, lang)
  if not ok or not parser then
    return results
  end

  local parse_ok, trees = pcall(parser.parse, parser)
  if not parse_ok or not trees or #trees == 0 then
    return results
  end

  local query_str = [[
    (string_fragment) @text
    (template_string) @text
    (jsx_text) @text
  ]]

  local query_ok, query = pcall(vim.treesitter.query.parse, lang, query_str)
  if not query_ok or not query then
    return results
  end

  local root = trees[1]:root()

  for _, node in query:iter_captures(root, source) do
    if is_import_parent(node) then
      goto continue
    end

    local start_row = node:start()
    local text = vim.treesitter.get_node_text(node, source)

    if not text or #vim.trim(text) < 3 then
      goto continue
    end

    local line_text = lines[start_row + 1] or ''

    table.insert(results, {
      file = filepath,
      pos = { start_row + 1, 0 },
      text = vim.trim(line_text),
    })

    ::continue::
  end

  return results
end

function M.search_user_text()
  local files = vim.fn.systemlist('git ls-files "*.ts" "*.tsx" "*.js" "*.jsx"')

  if not files or #files == 0 then
    vim.notify('No TypeScript/JavaScript files found', vim.log.levels.INFO)
    return
  end

  local items = {}

  for _, filepath in ipairs(files) do
    if not is_test_file(filepath) then
      local texts = collect_texts_from_file(filepath)
      for _, item in ipairs(texts) do
        table.insert(items, item)
      end
    end
  end

  vim.schedule(function()
    if #items == 0 then
      vim.notify('No user-facing text found', vim.log.levels.INFO)
      return
    end

    local ok, snacks = pcall(require, 'snacks')
    if not ok then
      return
    end

    snacks.picker({
      title = 'User-Facing Text',
      items = items,
      preview = 'file',
      format = function(item)
        local icon, hl = snacks.util.icon(item.file, 'file')
        return { { icon, hl }, { ' ' }, { item.text } }
      end,
      confirm = function(picker, item)
        picker:close()
        vim.cmd('edit ' .. vim.fn.fnameescape(item.file))
        vim.api.nvim_win_set_cursor(0, { item.pos[1], item.pos[2] })
      end,
    })
  end)
end

return M
