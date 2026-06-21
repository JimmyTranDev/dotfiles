local github_utils = require('custom.utils.github')

local M = {}

function M.copy_github_line_url()
  local repo_info = github_utils.get_repo_info()
  if not repo_info or not repo_info.nameWithOwner then
    vim.notify('Could not determine repository', vim.log.levels.ERROR)
    return
  end

  local file = vim.fn.expand('%:p')
  if file == '' then
    vim.notify('No file is currently open', vim.log.levels.WARN)
    return
  end

  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 or not git_root then
    vim.notify('Not in a git repository', vim.log.levels.ERROR)
    return
  end

  local relative_path = file:sub(#git_root + 2)

  local commit_hash = vim.fn.systemlist('git rev-parse HEAD')[1]
  if vim.v.shell_error ~= 0 or not commit_hash then
    vim.notify('Could not determine commit hash', vim.log.levels.ERROR)
    return
  end

  local mode = vim.fn.mode()
  local line_fragment
  if mode == 'v' or mode == 'V' or mode == '\22' then
    local start_line = vim.fn.line('v')
    local end_line = vim.fn.line('.')
    if start_line > end_line then
      start_line, end_line = end_line, start_line
    end
    if start_line == end_line then
      line_fragment = string.format('#L%d', start_line)
    else
      line_fragment = string.format('#L%d-L%d', start_line, end_line)
    end
  else
    line_fragment = string.format('#L%d', vim.fn.line('.'))
  end

  local url = string.format('https://github.com/%s/blob/%s/%s%s', repo_info.nameWithOwner, commit_hash, relative_path, line_fragment)

  vim.fn.setreg('+', url)
  vim.notify('Copied: ' .. url, vim.log.levels.INFO)
end

--- Parse a GitHub file URL from the clipboard and open the corresponding local file at the correct line
function M.open_file_from_clipboard_url()
  local clipboard = vim.fn.getreg('+')
  if not clipboard or clipboard == '' then
    vim.notify('Clipboard is empty', vim.log.levels.WARN)
    return
  end

  -- Extract path portion after blob/tree/raw in GitHub-like URLs
  local after_type = clipboard:match('https?://[^/]+/[^/]+/[^/]+/blob/(%S+)')
    or clipboard:match('https?://[^/]+/[^/]+/[^/]+/tree/(%S+)')
    or clipboard:match('https?://[^/]+/[^/]+/[^/]+/raw/(%S+)')

  if not after_type then
    vim.notify('No GitHub file URL found in clipboard', vim.log.levels.WARN)
    return
  end

  -- Split path from fragment (#L42, #L10-L20)
  local path_with_ref, fragment = after_type:match('^(.-)#(.*)$')
  if not path_with_ref then path_with_ref = after_type end

  -- Strip query parameters
  path_with_ref = path_with_ref:gsub('%?.*', '')

  -- Parse line number from fragment
  local line_num
  if fragment then line_num = tonumber(fragment:match('L(%d+)')) end

  -- Decode URL-encoded characters (%20, etc.)
  path_with_ref = path_with_ref:gsub('%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)

  -- Split into segments to handle refs with slashes (e.g. feature/my-branch)
  local segments = {}
  for seg in path_with_ref:gmatch('[^/]+') do
    table.insert(segments, seg)
  end

  if #segments < 2 then
    vim.notify('Could not parse file path from URL', vim.log.levels.WARN)
    return
  end

  local git_root = vim.fn.systemlist('git rev-parse --show-toplevel')[1]
  if vim.v.shell_error ~= 0 or not git_root then git_root = nil end

  -- Try progressively longer ref prefixes to find the file
  local resolved_path
  for i = 2, #segments do
    local candidate = table.concat(segments, '/', i)

    if vim.fn.filereadable(candidate) == 1 or vim.fn.isdirectory(candidate) == 1 then
      resolved_path = candidate
      break
    end

    if git_root then
      local full = git_root .. '/' .. candidate
      if vim.fn.filereadable(full) == 1 or vim.fn.isdirectory(full) == 1 then
        resolved_path = full
        break
      end
    end
  end

  if not resolved_path then
    local tried_path = table.concat(segments, '/', 2)
    vim.notify('File not found: ' .. tried_path, vim.log.levels.WARN)
    return
  end

  vim.cmd('edit ' .. vim.fn.fnameescape(resolved_path))

  if line_num then
    local line_count = vim.api.nvim_buf_line_count(0)
    if line_num > line_count then line_num = line_count end
    vim.api.nvim_win_set_cursor(0, { line_num, 0 })
  end

  local display_name = vim.fn.fnamemodify(resolved_path, ':t')
  if line_num then
    vim.notify('Opened ' .. display_name .. ':' .. line_num, vim.log.levels.INFO)
  else
    vim.notify('Opened ' .. display_name, vim.log.levels.INFO)
  end
end

return M
