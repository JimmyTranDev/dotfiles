local git_utils = require('custom.utils.git')
local link_utils = require('custom.utils.links')
local util = require('custom.actions.jira.util')

local parse_csv_line = util.parse_csv_line

local M = {}

M.copy_ticket_with_title = function()
  local branch_name = git_utils.get_current_branch()
  if not branch_name or branch_name == '' then
    vim.notify('Not in a git repository or no branch found', vim.log.levels.WARN)
    return
  end

  local jira_ticket = git_utils.extract_jira_ticket(branch_name)
  if not jira_ticket or jira_ticket == '' then
    vim.notify('No JIRA ticket found in branch name: ' .. branch_name, vim.log.levels.WARN)
    return
  end

  local jira_link = link_utils.get_jira_link_with_ticket(jira_ticket)

  local cmd = string.format('acli jira workitem view --key "%s" --fields "summary" --csv', jira_ticket)
  vim.system(
    { 'sh', '-c', cmd },
    { text = true },
    vim.schedule_wrap(function(result)
      local title = ''
      if result.code == 0 then
        local lines = vim.split(result.stdout, '\n', { trimempty = true })
        if #lines >= 2 then
          local fields = parse_csv_line(lines[2])
          if #fields >= 1 then title = fields[1] end
        end
      end

      if title == '' then
        local title_part = branch_name:match(jira_ticket:gsub('%-', '%%-') .. '[_%-](.+)') or ''
        title = title_part:gsub('[_%-]', ' ')
      end

      local ticket_with_title = jira_link and string.format('%s - %s', jira_link, title) or string.format('%s - %s', jira_ticket, title)

      vim.fn.setreg('+', ticket_with_title)
      vim.notify('Copied: ' .. ticket_with_title, vim.log.levels.INFO)
    end)
  )
end

M.copy_testable_message = function()
  local branch_name = git_utils.get_current_branch()
  if not branch_name or branch_name == '' then
    vim.notify('Not in a git repository or no branch found', vim.log.levels.WARN)
    return
  end

  local jira_ticket = git_utils.extract_jira_ticket(branch_name)
  if not jira_ticket or jira_ticket == '' then
    vim.notify('No JIRA ticket found in branch name: ' .. branch_name, vim.log.levels.WARN)
    return
  end

  local title_part = branch_name:match(jira_ticket:gsub('%-', '%%-') .. '[_%-](.+)') or ''
  local title = title_part:gsub('[_%-]', ' ')

  local jira_link = link_utils.get_jira_link_with_ticket(jira_ticket)
  local url = jira_link or jira_ticket
  local message = string.format('This Jira is now testable:\n%s - %s :hourglass:', url, title)

  vim.fn.setreg('+', message)
  vim.notify('Copied testable message', vim.log.levels.INFO)
end

function M.add_comment_from_branch()
  local branch = git_utils.get_current_branch()
  local ticket = git_utils.extract_jira_ticket(branch)

  if ticket == '' then
    vim.notify('No Jira ticket found in branch: ' .. branch, vim.log.levels.ERROR)
    return
  end

  vim.ui.input({
    prompt = 'Comment for ' .. ticket .. ': ',
  }, function(body)
    if not body or body == '' then return end

    vim.notify('Adding comment to ' .. ticket .. '...', vim.log.levels.INFO)

    vim.system(
      { 'acli', 'jira', 'workitem', 'comment', 'create', '--key', ticket, '--body', body },
      { text = true },
      vim.schedule_wrap(function(result)
        if result.code == 0 then
          vim.notify('Comment added to ' .. ticket, vim.log.levels.INFO)
        else
          vim.notify('Failed to add comment: ' .. (result.stderr or result.stdout), vim.log.levels.ERROR)
        end
      end)
    )
  end)
end

return M
