local input_utils = require('custom.utils.input')
local git_utils = require('custom.utils.git')
local link_utils = require('custom.utils.links')
local file_utils = require('custom.utils.files')
local ui_utils = require('custom.utils.ui')

local M = {}

local function get_jira_parent_epics()
  local epics_str = vim.env.ORG_JIRA_PARENT_EPICS
  if not epics_str or epics_str == '' then return {} end
  return vim.split(epics_str, '%s+', { trimempty = true })
end

local function get_jira_epics()
  local epics_str = vim.env.ORG_JIRA_EPICS
  if not epics_str or epics_str == '' then return {} end
  return vim.split(epics_str, '%s+', { trimempty = true })
end

local CONFIG = {
  CACHE_DIR = vim.fn.stdpath('data'),
  DEFAULT_PROJECT = 'BW',
  LIMIT = 50,
  AUTO_TRANSITION = true,
  TRANSITION_STATUSES = { 'In Progress Concept', 'Done Concept', 'Prioritised Issues Development' },
  -- Sentinel marking where the "Done Concept only" path stops within TRANSITION_STATUSES.
  -- Must exist in the chain above; the slice fails closed if it does not.
  DONE_CONCEPT_STATUS = 'Done Concept',
}

local ISSUE_TYPES = {
  { name = 'Task', value = 'Task' },
  { name = 'Bug', value = 'Bug' },
  { name = 'Subtask', value = 'Subtask' },
  { name = 'Story', value = 'Story' },
  { name = 'Epic', value = 'Epic' },
}

local LABELS = {
  { name = 'None', value = nil },
  { name = 'frontend', value = 'frontend' },
  { name = 'backend', value = 'backend' },
}

local cache_files = {
  last_parent = CONFIG.CACHE_DIR .. '/jira_last_parent.txt',
  parents = CONFIG.CACHE_DIR .. '/jira_parents_cache.txt',
}

local function save_last_parent(parent_key) file_utils.write_lines(cache_files.last_parent, { parent_key }) end

local function load_last_parent()
  local lines = file_utils.read_lines(cache_files.last_parent)
  if #lines > 0 then return lines[1]:match('^%s*(.-)%s*$') end
  return nil
end

local function save_parents_cache(parents) file_utils.write_lines(cache_files.parents, { vim.json.encode(parents) }) end

local function load_parents_cache()
  local lines = file_utils.read_lines(cache_files.parents)
  if #lines > 0 then
    local content = table.concat(lines, '\n'):match('^%s*(.-)%s*$')
    if content then
      local success, parents = pcall(vim.json.decode, content)
      if success and parents then return parents end
    end
  end
  return nil
end

local function get_current_user_email()
  local email = os.getenv('ORG_EMAIL')
  return email and email:match('^%s*(.-)%s*$')
end

local function parse_csv_line(line)
  local fields = {}
  local field = ''
  local in_quotes = false
  local i = 1

  while i <= #line do
    local char = line:sub(i, i)
    if char == '"' then
      in_quotes = not in_quotes
    elseif char == ',' and not in_quotes then
      table.insert(fields, field:match('^%s*(.-)%s*$'))
      field = ''
    else
      field = field .. char
    end
    i = i + 1
  end

  table.insert(fields, field:match('^%s*(.-)%s*$'))
  return fields
end

local function create_parent_entry(key, summary, status)
  return {
    key = key,
    summary = summary,
    status = status,
    display = string.format('%s - %s (%s)', key, summary, status),
  }
end

local function build_parent_options(parents)
  local last_parent = load_last_parent()
  local options = {}
  local last_used_option = nil

  for _, parent in ipairs(parents) do
    local option = { name = parent.display, value = parent.key }
    if last_parent and parent.key == last_parent then
      option.name = option.name .. ' (Last used)'
      last_used_option = option
    else
      table.insert(options, option)
    end
  end

  if last_used_option then table.insert(options, 1, last_used_option) end
  return options
end

local function get_user_input(prompt, callback, default)
  input_utils.get_input(prompt, function(input)
    if not input then
      vim.notify('Task creation cancelled', vim.log.levels.INFO)
      return
    end
    callback(input)
  end, default or '')
end

local function fetch_parent_issues(callback, force_refresh)
  if not force_refresh then
    local cached_parents = load_parents_cache()
    if cached_parents then
      vim.notify('Using cached parent issues', vim.log.levels.INFO)
      callback(cached_parents)
      return
    end
  end

  local parent_epics = get_jira_parent_epics()
  local direct_epics = get_jira_epics()
  if #parent_epics == 0 and #direct_epics == 0 then
    vim.notify('ORG_JIRA_PARENT_EPICS and ORG_JIRA_EPICS environment variables not set', vim.log.levels.ERROR)
    callback(nil)
    return
  end

  local jql_parts = {}
  if #parent_epics > 0 then
    local epic_clauses = {}
    for _, epic in ipairs(parent_epics) do
      table.insert(epic_clauses, 'issuekey in portfolioChildIssuesOf(' .. epic .. ')')
    end
    table.insert(jql_parts, '(' .. table.concat(epic_clauses, ' OR ') .. ')')
  end
  if #direct_epics > 0 then
    local keys = table.concat(direct_epics, ', ')
    table.insert(jql_parts, 'issuekey in (' .. keys .. ')')
  end

  local jql_query = 'project = "'
    .. CONFIG.DEFAULT_PROJECT
    .. '" AND ('
    .. table.concat(jql_parts, ' OR ')
    .. ') AND issuetype in (Initiative, Epic)'
    .. ' ORDER BY parent'
  local cmd = string.format('acli jira workitem search --jql "%s" --fields "key,summary,status" --limit %d --csv', jql_query, CONFIG.LIMIT)

  vim.notify('Fetching available parent issues...', vim.log.levels.INFO)

  vim.system(
    { 'sh', '-c', cmd },
    { text = true },
    vim.schedule_wrap(function(result)
      if result.code ~= 0 then
        local error_msg = result.stderr ~= '' and result.stderr or result.stdout
        vim.notify('Failed to fetch parent issues: ' .. error_msg, vim.log.levels.ERROR)
        callback(nil)
        return
      end

      local parents = {}
      local lines = vim.split(result.stdout, '\n', { trimempty = true })

      for i = 2, #lines do
        local line = lines[i]
        if line:match('^[^,]*BW%-') then
          local fields = parse_csv_line(line)
          if #fields >= 3 then table.insert(parents, create_parent_entry(fields[1], fields[3], fields[2])) end
        end
      end

      if #parents > 0 then
        save_parents_cache(parents)
        callback(parents)
      else
        vim.notify('No parent issues found', vim.log.levels.WARN)
        callback(nil)
      end
    end)
  )
end

local function create_jira_task_workflow(summary, description, fallback_project, should_open_link)
  local select_project, select_type, select_label, select_parent

  select_project = function()
    get_user_input('Enter project key: ', function(project) select_type(project) end, fallback_project)
  end

  select_type = function(project)
    local type_options = vim.tbl_deep_extend('force', {}, ISSUE_TYPES)
    ui_utils.add_back_option(type_options, 'Back to project')

    vim.ui.select(type_options, {
      prompt = 'Select work item type:',
      format_item = function(item) return item.name end,
    }, function(selected_type)
      if not selected_type then
        vim.notify('Task creation cancelled', vim.log.levels.INFO)
        return
      end

      if selected_type.value == '__back__' then
        select_project()
        return
      end

      select_label(project, selected_type)
    end)
  end

  select_label = function(project, selected_type)
    local label_options = vim.tbl_deep_extend('force', {}, LABELS)
    ui_utils.add_back_option(label_options, 'Back to type')

    vim.ui.select(label_options, {
      prompt = 'Select label:',
      format_item = function(item) return item.name end,
    }, function(selected_label)
      if not selected_label then
        vim.notify('Task creation cancelled', vim.log.levels.INFO)
        return
      end

      if selected_label.value == '__back__' then
        select_type(project)
        return
      end

      select_parent(project, selected_type, selected_label)
    end)
  end

  select_parent = function(project, selected_type, selected_label)
    fetch_parent_issues(function(parents)
      if not parents then
        vim.notify('Failed to fetch parent issues - task creation cancelled', vim.log.levels.ERROR)
        return
      end

      local parent_options = build_parent_options(parents)
      ui_utils.add_back_option(parent_options, 'Back to label')

      vim.ui.select(parent_options, {
        prompt = 'Select parent issue:',
        format_item = function(item) return item.name end,
      }, function(selected_parent)
        if not selected_parent then
          vim.notify('Task creation cancelled', vim.log.levels.INFO)
          return
        end

        if selected_parent.value == '__back__' then
          select_label(project, selected_type)
          return
        end

        save_last_parent(selected_parent.value)

        local assignee_email = get_current_user_email()
        local assignee_flag = assignee_email and string.format(' --assignee "%s"', assignee_email) or ''
        local label_flag = selected_label.value and string.format(' --label "%s"', selected_label.value) or ''
        local description_flag = (description and description ~= '') and string.format(' --description "%s"', description:gsub('"', '\\"')) or ''

        local cmd = string.format(
          'acli jira workitem create --summary "%s" --project "%s" --type "%s" --parent "%s"%s%s%s',
          summary:gsub('"', '\\"'),
          project,
          selected_type.value,
          selected_parent.value,
          assignee_flag,
          label_flag,
          description_flag
        )

        vim.notify('Creating Jira task...', vim.log.levels.INFO)

        vim.system(
          { 'sh', '-c', cmd },
          { text = true },
          vim.schedule_wrap(function(result)
            if result.code == 0 then
              local work_item_id = result.stdout:match('([A-Z]+-[0-9]+)')

              if work_item_id then
                vim.notify(string.format('Task %s created successfully', work_item_id), vim.log.levels.INFO)

                if CONFIG.AUTO_TRANSITION then
                  local function run_transitions(statuses, index, on_complete)
                    if index > #statuses then
                      on_complete()
                      return
                    end

                    local status = statuses[index]
                    local transition_cmd = string.format('acli jira workitem transition --key "%s" --status "%s" --yes', work_item_id, status)

                    vim.system(
                      { 'sh', '-c', transition_cmd },
                      { text = true },
                      vim.schedule_wrap(function(transition_result)
                        if transition_result.code == 0 then
                          vim.notify(string.format('Task %s transitioned to %s', work_item_id, status), vim.log.levels.INFO)
                          run_transitions(statuses, index + 1, on_complete)
                        else
                          local transition_error = transition_result.stderr ~= '' and transition_result.stderr or transition_result.stdout
                          vim.notify(string.format('Task %s failed to transition to %s: %s', work_item_id, status, transition_error), vim.log.levels.WARN)
                          on_complete()
                        end
                      end)
                    )
                  end

                  local transition_options = {
                    { name = 'Done Concept only', value = 'done_concept' },
                    { name = 'Prioritise', value = 'prioritise' },
                  }

                  vim.ui.select(transition_options, {
                    prompt = 'Select transition target:',
                    format_item = function(item) return item.name end,
                  }, function(selected_transition)
                    -- Default to Done Concept only (safer, non-final) when the prompt is dismissed
                    local transition_choice = selected_transition and selected_transition.value or 'done_concept'

                    local statuses = CONFIG.TRANSITION_STATUSES
                    if transition_choice == 'done_concept' then
                      -- Slice the configured chain up to and including the Done Concept sentinel
                      -- rather than duplicating a status list, so this tracks TRANSITION_STATUSES.
                      local subset = {}
                      local found = false
                      for _, status in ipairs(CONFIG.TRANSITION_STATUSES) do
                        table.insert(subset, status)
                        if status == CONFIG.DONE_CONCEPT_STATUS then
                          found = true
                          break
                        end
                      end
                      -- Fail closed: if the sentinel is missing (e.g. chain renamed), do NOT fall
                      -- through to the full chain and over-transition past Done Concept — abort instead.
                      if not found then
                        vim.notify(
                          string.format(
                            "Transition status '%s' not in chain; skipping auto-transition",
                            CONFIG.DONE_CONCEPT_STATUS
                          ),
                          vim.log.levels.WARN
                        )
                        subset = {}
                      end
                      statuses = subset
                    end

                    run_transitions(statuses, 1, function()
                      if should_open_link then
                        local jira_link = link_utils.get_jira_link_with_ticket(work_item_id)
                        if jira_link then vim.system({ 'open', jira_link }) end
                      end
                    end)
                  end)
                else
                  if should_open_link then
                    local jira_link = link_utils.get_jira_link_with_ticket(work_item_id)
                    if jira_link then vim.system({ 'open', jira_link }) end
                  end
                end
              else
                vim.notify(string.format("Jira task '%s' created in project '%s'", summary, project), vim.log.levels.INFO)
              end
            else
              local error_msg = result.stderr ~= '' and result.stderr or result.stdout
              vim.notify('Failed to create Jira task: ' .. error_msg, vim.log.levels.ERROR)

              vim.ui.select(
                { { name = 'Try again', value = 'retry' }, { name = 'Cancel', value = 'cancel' } },
                { prompt = 'Task creation failed. What would you like to do?' },
                function(choice)
                  if choice and choice.value == 'retry' then select_project() end
                end
              )
            end
          end)
        )
      end)
    end)
  end

  select_project()
end

local function create_task_handler(should_open_link)
  return function(fallback_project)
    return function()
      get_user_input('Enter task summary: ', function(summary)
        vim.ui.input({ prompt = 'Enter description (optional): ' }, function(description)
          create_jira_task_workflow(summary, description, fallback_project or CONFIG.DEFAULT_PROJECT, should_open_link)
        end)
      end)
    end
  end
end

M.create_jira_task = create_task_handler(false)
M.create_jira_task_with_link = create_task_handler(true)

M.refresh_jira_cache = function()
  os.remove(cache_files.parents)
  vim.notify('Jira parent cache refreshed. Next task creation will fetch fresh data.', vim.log.levels.INFO)
end

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

      local ticket_with_title = jira_link
        and string.format('%s - %s', jira_link, title)
        or string.format('%s - %s', jira_ticket, title)

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
