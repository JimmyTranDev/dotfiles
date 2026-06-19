local file_utils = require('custom.utils.files')

local M = {}

function M.grep_markdown_headings()
  local snacks = require('snacks')

  snacks.picker.grep({
    search = '^#{1,6} ',
    prompt = 'Markdown Headings',
    title = 'Find Markdown Headings',
    rg = {
      '--type=md',
      '--line-number',
      '--column',
      '--smart-case',
      '--no-heading',
      '--color=never',
    },
    layout = {
      preset = 'default',
      preview = true,
    },
    format = function(item)
      local text = item.text or ''
      local level = text:match('^(#{1,6})')
      local heading_text = text:match('^#{1,6}%s*(.*)')

      if level and heading_text then
        local indent = string.rep('  ', #level - 1)
        return {
          { item.filename and vim.fn.fnamemodify(item.filename, ':t') or '', 'Comment' },
          { ':' .. (item.lnum or ''), 'LineNr' },
          { ' ' },
          { indent .. level .. ' ' .. heading_text, 'Normal' },
        }
      else
        return { { item.text or '', 'Normal' } }
      end
    end,
  })
end

function M.open_current_dir()
  local dir = vim.fn.expand('%:p:h')
  if dir ~= '' then
    file_utils.open(dir)
  else
    vim.notify('No current file directory found', vim.log.levels.WARN)
  end
end

function M.yank_word_and_open()
  vim.cmd('normal! "ayW')
  local word = vim.fn.getreg('a')
  if word == '' then
    vim.notify('No word under cursor', vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(vim.cmd, 'edit ' .. word)
  if not ok then vim.notify('Failed to open file: ' .. err, vim.log.levels.ERROR) end
end

function M.copy_all_files_content()
  if vim.fn.expand('%:p') == '' then
    vim.notify('No current file', vim.log.levels.WARN)
    return
  end
  vim.fn.setreg('+', file_utils.get_recursive_file_contents())
  vim.notify('Copied all files content to clipboard', vim.log.levels.INFO)
end

function M.save_clipboard_to_file()
  local content = vim.fn.getreg('+')
  if content == '' then
    vim.notify('Clipboard is empty', vim.log.levels.WARN)
    return
  end

  vim.ui.input({ prompt = 'Enter filename: ' }, function(filename)
    if not filename or filename == '' then return end
    local path = vim.fn.expand('%:p:h') .. '/' .. filename
    local file = io.open(path, 'w')
    if file then
      file:write(content)
      file:close()
      vim.notify('File saved: ' .. path, vim.log.levels.INFO)
    else
      vim.notify('Could not create file', vim.log.levels.ERROR)
    end
  end)
end

function M.copy_current_file_url()
  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end
  local url = 'file://' .. file
  vim.fn.setreg('+', url)
  vim.notify('Copied: ' .. url, vim.log.levels.INFO)
end

function M.copy_opencode_link()
  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end
  local link = ('@%s:%d'):format(vim.fn.fnamemodify(file, ':.'), vim.fn.line('.'))
  vim.fn.setreg('+', link)
  vim.notify('Copied: ' .. link, vim.log.levels.INFO)
end

function M.copy_ai_file_reference()
  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end
  local link = ('@%s:%d'):format(vim.fn.fnamemodify(file, ':.'), vim.fn.line('.'))
  vim.fn.setreg('+', link)
  vim.notify('Copied: ' .. link, vim.log.levels.INFO)
end

function M.copy_ai_file_reference_range()
  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end
  local start_line = vim.fn.line('v')
  local end_line = vim.fn.line('.')
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local rel = vim.fn.fnamemodify(file, ':.')
  local link
  if start_line == end_line then
    link = ('@%s:%d'):format(rel, start_line)
  else
    link = ('@%s:%d-%d'):format(rel, start_line, end_line)
  end
  vim.fn.setreg('+', link)
  vim.notify('Copied: ' .. link, vim.log.levels.INFO)
end

function M.copy_as_markdown_code_block()
  if vim.fn.expand('%:p') == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end
  local lang = vim.bo.filetype
  local content = table.concat(vim.fn.getline(1, '$'), '\n')
  local block = string.format('```%s\n%s\n```', lang, content)
  vim.fn.setreg('+', block)
  vim.notify('Copied buffer as markdown code block', vim.log.levels.INFO)
end

function M.copy_as_markdown_code_block_range()
  if vim.fn.expand('%:p') == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end
  local start_line = vim.fn.line('v')
  local end_line = vim.fn.line('.')
  if start_line > end_line then
    start_line, end_line = end_line, start_line
  end
  local lang = vim.bo.filetype
  local content = table.concat(vim.fn.getline(start_line, end_line), '\n')
  local block = string.format('```%s\n%s\n```', lang, content)
  vim.fn.setreg('+', block)
  vim.notify('Copied selection as markdown code block', vim.log.levels.INFO)
end

function M.copy_frontend_project_paths()
  local base_dir = vim.fn.expand('~/Programming')
  local stat = vim.uv.fs_stat(base_dir)
  if not stat or stat.type ~= 'directory' then
    vim.notify('Directory not found: ' .. base_dir, vim.log.levels.WARN)
    return
  end

  local paths = {}
  local handle = vim.uv.fs_scandir(base_dir)
  if not handle then
    vim.notify('Could not scan: ' .. base_dir, vim.log.levels.WARN)
    return
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if type == 'directory' then
      local pkg_path = base_dir .. '/' .. name .. '/package.json'
      local pkg_stat = vim.uv.fs_stat(pkg_path)
      if pkg_stat then
        table.insert(paths, base_dir .. '/' .. name)
      end
    end
  end

  if #paths == 0 then
    vim.notify('No frontend projects found', vim.log.levels.INFO)
    return
  end

  table.sort(paths)
  local result = table.concat(paths, '\n')
  vim.fn.setreg('+', result)
  vim.notify('Copied ' .. #paths .. ' frontend project paths', vim.log.levels.INFO)
end

function M.copy_repo_path()
  local cwd = vim.fn.getcwd()
  vim.fn.setreg('+', cwd)
  vim.notify('Copied: ' .. cwd, vim.log.levels.INFO)
end

function M.convert_md_to_pdf()
  local filepath = vim.fn.expand('%:p')
  if not filepath:match('%.md$') then
    vim.notify('Not a markdown file', vim.log.levels.WARN)
    return
  end

  local pdf_path = filepath:gsub('%.md$', '.pdf')
  local cmd = { 'pandoc', filepath, '-o', pdf_path, '--pdf-engine=pdflatex' }

  vim.notify('Converting to PDF...', vim.log.levels.INFO)

  vim.system(
    cmd,
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code == 0 then
        vim.notify('PDF saved: ' .. pdf_path, vim.log.levels.INFO)
      else
        local err = result.stderr ~= '' and result.stderr or result.stdout
        vim.notify('PDF conversion failed: ' .. err, vim.log.levels.ERROR)
      end
    end)
  )
end

function M.grep_current_file_dir()
  local dir = vim.fn.expand('%:p:h')
  if dir == '' then
    vim.notify('No file open', vim.log.levels.WARN)
    return
  end
  Snacks.picker.grep({ cwd = dir, hidden = true, ignored = true })
end

function M.find_plan_files()
  Snacks.picker.files({ cwd = vim.fn.getcwd() .. '/plans' })
end

function M.clear_plan_files()
  local plans_dir = vim.fn.getcwd() .. '/plans'
  local stat = vim.uv.fs_stat(plans_dir)
  if not stat or stat.type ~= 'directory' then
    vim.notify('No plans/ directory found', vim.log.levels.WARN)
    return
  end

  local files = {}
  local handle = vim.uv.fs_scandir(plans_dir)
  if not handle then
    vim.notify('Could not read plans/ directory', vim.log.levels.WARN)
    return
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then break end
    if type == 'file' then
      table.insert(files, name)
    end
  end

  if #files == 0 then
    vim.notify('No plan files to clear', vim.log.levels.INFO)
    return
  end

  local msg = string.format('Delete %d plan file(s)?', #files)
  vim.ui.select({ 'Yes', 'No' }, { prompt = msg }, function(choice)
    if choice ~= 'Yes' then return end
    local deleted = 0
    for _, filename in ipairs(files) do
      local ok = os.remove(plans_dir .. '/' .. filename)
      if ok then
        deleted = deleted + 1
      else
        vim.notify('Failed to delete: ' .. filename, vim.log.levels.ERROR)
      end
    end
    vim.notify('Deleted ' .. deleted .. ' plan file(s)', vim.log.levels.INFO)
  end)
end

return M
