local input_utils = require('custom.utils.input')
local link_utils = require('custom.utils.links')
local file_utils = require('custom.utils.files')
local ui_utils = require('custom.utils.ui')
local util = require('custom.actions.jira.util')

local CONFIG = util.CONFIG
local get_current_user_email = util.get_current_user_email
local parse_csv_line = util.parse_csv_line

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

                local function open_link_if_requested()
                  if should_open_link then
                    local jira_link = link_utils.get_jira_link_with_ticket(work_item_id)
                    if jira_link then vim.system({ 'open', jira_link }) end
                  end
                end

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

                  -- Offer each configured status as a target; selecting one runs the chain
                  -- from the start up to and including it (Jira requires stepping through the
                  -- intermediate states). Dismissing the picker skips the transition entirely.
                  local transition_options = {}
                  for _, status in ipairs(CONFIG.TRANSITION_STATUSES) do
                    table.insert(transition_options, { name = status, value = status })
                  end

                  vim.ui.select(transition_options, {
                    prompt = 'Select transition target:',
                    format_item = function(item) return item.name end,
                  }, function(selected_transition)
                    -- Dismissed: leave the ticket in its just-created state, no transition.
                    if not selected_transition then
                      open_link_if_requested()
                      return
                    end

                    -- Fail closed: an unrecognised target slices to an empty chain rather
                    -- than running every status by accident.
                    local statuses = util.slice_transition_chain(CONFIG.TRANSITION_STATUSES, selected_transition.value)
                    if #statuses == 0 then
                      vim.notify(
                        string.format("Transition status '%s' not in chain; skipping auto-transition", tostring(selected_transition.value)),
                        vim.log.levels.WARN
                      )
                    end

                    run_transitions(statuses, 1, open_link_if_requested)
                  end)
                else
                  open_link_if_requested()
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
        vim.ui.input(
          { prompt = 'Enter description (optional): ' },
          function(description) create_jira_task_workflow(summary, description, fallback_project or CONFIG.DEFAULT_PROJECT, should_open_link) end
        )
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

return M
