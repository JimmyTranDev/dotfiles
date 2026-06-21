local link_utils = require('custom.utils.links')
local file_utils = require('custom.utils.files')
local util = require('custom.actions.jira.util')

local CONFIG = util.CONFIG
local get_current_user_email = util.get_current_user_email
local parse_csv_line = util.parse_csv_line

local M = {}

M.generate_done_md = function()
  local assignee_email = get_current_user_email()
  if not assignee_email then
    vim.notify('ORG_EMAIL environment variable not set', vim.log.levels.ERROR)
    return
  end

  local escaped_email = assignee_email:gsub('@', '\\u0040')
  local jql_query = string.format("assignee was '%s' AND updated >= -7d ORDER BY updated DESC", escaped_email)

  local cmd = string.format('acli jira workitem search --jql "%s" --fields \'key,summary,status\' --limit 100 --csv', jql_query)

  vim.notify('Fetching completed tasks...', vim.log.levels.INFO)

  vim.system(
    { 'sh', '-c', cmd },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        local error_msg = result.stderr ~= '' and result.stderr or result.stdout
        vim.notify('Failed to fetch tasks: ' .. error_msg, vim.log.levels.ERROR)
        return
      end

      local lines = vim.split(result.stdout, '\n', { trimempty = true })
      if #lines <= 1 then
        vim.notify('No completed tasks found', vim.log.levels.WARN)
        return
      end

      local md_lines = { '# Done Tasks', '', '| Ticket | Summary | Status |', '|--------|---------|--------|' }

      for i = 2, #lines do
        local fields = parse_csv_line(lines[i])
        if #fields >= 3 then
          local key = fields[1]
          local status = fields[2]
          local summary = fields[3]:gsub('|', '\\|')
          local jira_link = link_utils.get_jira_link_with_ticket(key)
          local ticket_link = jira_link and string.format('[%s](%s)', key, jira_link) or key
          table.insert(md_lines, string.format('| %s | %s | %s |', ticket_link, summary, status))
        end
      end

      local root_dir = vim.fn.getcwd()
      local done_file = root_dir .. '/DONE.md'

      if file_utils.write_lines(done_file, md_lines) then
        vim.notify(string.format('Generated %s with %d tasks', done_file, #lines - 1), vim.log.levels.INFO)
      else
        vim.notify('Failed to write DONE.md', vim.log.levels.ERROR)
      end
    end)
  )
end

local function browse_tasks(opts)
  local assignee_email = get_current_user_email()
  if not assignee_email then
    vim.notify('ORG_EMAIL environment variable not set', vim.log.levels.ERROR)
    return
  end

  local escaped_email = assignee_email:gsub('@', '\\u0040')
  local jql_query = string.format(opts.jql, escaped_email)

  local cmd = string.format('acli jira workitem search --jql "%s" --fields "key,summary,status" --limit %d --csv', jql_query, CONFIG.LIMIT)

  vim.notify(opts.fetching_msg, vim.log.levels.INFO)

  vim.system(
    { 'sh', '-c', cmd },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        local error_msg = result.stderr ~= '' and result.stderr or result.stdout
        vim.notify('Failed to fetch tasks: ' .. error_msg, vim.log.levels.ERROR)
        return
      end

      local lines = vim.split(result.stdout, '\n', { trimempty = true })
      if #lines <= 1 then
        vim.notify(opts.empty_msg, vim.log.levels.WARN)
        return
      end

      local items = {}
      for i = 2, #lines do
        local fields = parse_csv_line(lines[i])
        if #fields >= 3 then
          local key = fields[1]
          local status = fields[2]
          local summary = fields[3]
          table.insert(items, {
            text = string.format('%s  %s  [%s]', key, summary, status),
            key = key,
            summary = summary,
            status = status,
          })
        end
      end

      if #items == 0 then
        vim.notify(opts.empty_msg, vim.log.levels.WARN)
        return
      end

      Snacks.picker({
        title = opts.title,
        items = items,
        format = function(item)
          return {
            { item.key .. '  ', 'DiagnosticInfo' },
            { item.summary .. '  ', 'Normal' },
            { '[' .. item.status .. ']', 'Comment' },
          }
        end,
        confirm = function(picker, item)
          picker:close()
          local jira_link = link_utils.get_jira_link_with_ticket(item.key)
          if jira_link then
            vim.system({ 'open', jira_link })
          else
            vim.notify('Could not build Jira link for ' .. item.key, vim.log.levels.ERROR)
          end
        end,
      })
    end)
  )
end

M.browse_my_tasks = function()
  browse_tasks({
    jql = "assignee = '%s' AND status not in (Done, Closed, Resolved) ORDER BY updated DESC",
    fetching_msg = 'Fetching your Jira tasks...',
    empty_msg = 'No tasks found',
    title = 'My Jira Tasks',
  })
end

M.browse_recently_updated_tasks = function()
  browse_tasks({
    jql = "assignee = '%s' AND updated >= -7d ORDER BY updated DESC",
    fetching_msg = 'Fetching recently updated Jira tasks...',
    empty_msg = 'No recently updated tasks found',
    title = 'Recently Updated Jira Tasks',
  })
end

return M
