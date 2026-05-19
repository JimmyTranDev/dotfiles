local M = {}

local LAZY_REPO = 'https://github.com/folke/lazy.nvim.git'
local LAZY_BRANCH = 'stable'

local function is_git_available()
  local result = vim.fn.system('git --version')
  return vim.v.shell_error == 0 and result and result:match('git version') ~= nil
end

local function show_error_and_exit(title, message, details)
  local echo_content = {
    { title .. '\n', 'ErrorMsg' },
    { message .. '\n', 'WarningMsg' },
  }

  if details then
    table.insert(echo_content, { '\nDetails:\n', 'Normal' })
    table.insert(echo_content, { details .. '\n', 'Comment' })
  end

  table.insert(echo_content, { '\nPress any key to exit...', 'Normal' })

  vim.api.nvim_echo(echo_content, true, {})
  vim.fn.getchar()
  os.exit(1)
end

local function validate_lazy_installation(lazypath)
  local init_file = lazypath .. '/lua/lazy/init.lua'
  local stat = vim.uv.fs_stat(init_file)

  return stat and stat.type == 'file'
end

function M.bootstrap()
  local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'

  if vim.uv.fs_stat(lazypath) then
    if validate_lazy_installation(lazypath) then
      vim.opt.rtp:prepend(lazypath)
      return true
    else
      vim.notify('Removing corrupted lazy.nvim installation...', vim.log.levels.WARN)
      vim.fn.system({ 'rm', '-rf', lazypath })
    end
  end

  if not is_git_available() then
    show_error_and_exit('Git not found!', 'Git is required to install lazy.nvim but was not found on your system.', 'Please install git and try again.')
    return false
  end

  vim.notify('Installing lazy.nvim...', vim.log.levels.INFO)

  local clone_cmd = {
    'git',
    'clone',
    '--filter=blob:none',
    '--branch=' .. LAZY_BRANCH,
    LAZY_REPO,
    lazypath,
  }

  local output = vim.fn.system(clone_cmd)

  if vim.v.shell_error ~= 0 then
    local error_msg = 'The git clone operation failed.'
    if output:match('network') or output:match('connection') or output:match('resolve') then
      error_msg = error_msg .. '\nThis appears to be a network connectivity issue.'
    elseif output:match('permission') or output:match('access') then
      error_msg = error_msg .. '\nThis appears to be a file permission issue.'
    end

    show_error_and_exit('Failed to clone lazy.nvim!', error_msg, output)
    return false
  end

  if not validate_lazy_installation(lazypath) then
    show_error_and_exit(
      'Invalid lazy.nvim installation!',
      'lazy.nvim was cloned but appears to be corrupted.',
      'Try removing ' .. lazypath .. ' and restarting Neovim.'
    )
    return false
  end

  vim.opt.rtp:prepend(lazypath)

  vim.notify('lazy.nvim installed successfully!', vim.log.levels.INFO)
  return true
end

M.bootstrap()

return M
