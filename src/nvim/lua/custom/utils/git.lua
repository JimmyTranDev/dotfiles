local M = {}

local function run_cmd(cmd)
  local result = vim.fn.system(cmd .. ' 2>/dev/null')
  if vim.v.shell_error ~= 0 then return nil end
  return result:match('^([^\n]*)')
end

function M.get_current_branch() return run_cmd('git rev-parse --abbrev-ref HEAD') or '' end

function M.extract_jira_ticket(branch_name)
  if type(branch_name) ~= 'string' then return '' end
  return branch_name:match('([a-zA-Z]+%-%d+)_') or branch_name:match('([a-zA-Z]+%-%d+)') or ''
end

function M.sync_notes_repo()
  local repo = vim.fn.expand('~/Programming/JimmyTranDev/notes')
  vim.system({ 'git', '-C', repo, 'add', '.' }, {}, function(add_result)
    if add_result.code ~= 0 then return end

    vim.system({ 'git', '-C', repo, 'log', '-1', '--format=%s' }, {}, function(log_result)
      local week = tonumber(os.date('%W'))
      local year = tonumber(os.date('%Y'))
      local last_log = (log_result.stdout or ''):gsub('%s+$', '')
      local expected_msg = string.format('journal: week %d %d', week, year)

      local commit_args
      if last_log == expected_msg then
        commit_args = { 'git', '-C', repo, 'commit', '--amend', '--no-edit' }
      else
        commit_args = { 'git', '-C', repo, 'commit', '-m', expected_msg }
      end

      vim.system(commit_args, {}, function(commit_result)
        if commit_result.code ~= 0 then return end
        vim.system({ 'git', '-C', repo, 'push', '--force-with-lease' })
      end)
    end)
  end)
end

return M
