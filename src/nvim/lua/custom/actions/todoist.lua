local todoist_utils = require('custom.utils.todoist')
local json_utils = require('custom.utils.json')
local ui_utils = require('custom.utils.ui')
local async_utils = require('custom.utils.async')

local M = {}

local PRIORITY_OPTIONS = {
  { name = 'Top', value = 'p1' },
  { name = 'High', value = 'p2' },
  { name = 'Medium', value = 'p3' },
  { name = 'Low', value = 'p4' },
  { name = 'None', value = nil },
}

local RECENT_PROJECTS_FILE = vim.fn.stdpath('data') .. '/todoist_recent_projects.json'
local RECENT_SECTIONS_FILE = vim.fn.stdpath('data') .. '/todoist_recent_sections.json'
local MAX_RECENT_PROJECTS = 10
local MAX_RECENT_SECTIONS = 10

local format_by_name = function(item) return item.name end

local function get_recent_projects()
  if not vim.uv.fs_stat(RECENT_PROJECTS_FILE) then return {} end
  local data = json_utils.parse_json_from_file(RECENT_PROJECTS_FILE)
  if type(data) == 'table' and data.recent_projects then return data.recent_projects end
  return {}
end

local function save_recent_projects(recent_projects) json_utils.write_json_to_file(RECENT_PROJECTS_FILE, { recent_projects = recent_projects }) end

local function add_recent_project_id(id)
  local recent_projects = get_recent_projects()

  for i, project_id in ipairs(recent_projects) do
    if project_id == id then
      table.remove(recent_projects, i)
      break
    end
  end

  table.insert(recent_projects, 1, id)

  while #recent_projects > MAX_RECENT_PROJECTS do
    table.remove(recent_projects, #recent_projects)
  end

  save_recent_projects(recent_projects)
end

local function build_project_priority_map()
  local recent_projects = get_recent_projects()
  local map = {}
  for i, project_id in ipairs(recent_projects) do
    map[project_id] = i - 1
  end
  return map
end

local function get_recent_sections()
  if not vim.uv.fs_stat(RECENT_SECTIONS_FILE) then return {} end
  local data = json_utils.parse_json_from_file(RECENT_SECTIONS_FILE)
  if type(data) == 'table' and data.recent_sections then return data.recent_sections end
  return {}
end

local function save_recent_sections(recent_sections) json_utils.write_json_to_file(RECENT_SECTIONS_FILE, { recent_sections = recent_sections }) end

local function add_recent_section_id(id)
  local recent_sections = get_recent_sections()

  for i, section_id in ipairs(recent_sections) do
    if section_id == id then
      table.remove(recent_sections, i)
      break
    end
  end

  table.insert(recent_sections, 1, id)

  while #recent_sections > MAX_RECENT_SECTIONS do
    table.remove(recent_sections, #recent_sections)
  end

  save_recent_sections(recent_sections)
end

local function build_section_priority_map()
  local recent_sections = get_recent_sections()
  local map = {}
  for i, section_id in ipairs(recent_sections) do
    map[section_id] = i - 1
  end
  return map
end

local function create_task_with_navigation(task_name, projects, opts, on_back_to_description)
  local select_project, select_section, select_priority

  select_project = function()
    local priority_map = build_project_priority_map()

    table.sort(projects, function(a, b)
      local a_priority = priority_map[a.id] or 999
      local b_priority = priority_map[b.id] or 999

      if a_priority ~= b_priority then return a_priority < b_priority end
      if a.child_order ~= b.child_order then return a.child_order < b.child_order end
      return a.name < b.name
    end)

    local project_options = {}
    for _, project in ipairs(projects) do
      table.insert(project_options, {
        name = project.name .. ' (' .. (project.color or 'grey') .. ')',
        id = project.id,
        project = project,
      })
    end

    ui_utils.safe_select(project_options, {
      prompt = 'Select a project:',
      format_item = format_by_name,
      on_back = on_back_to_description,
    }, function(selected)
      add_recent_project_id(selected.id)
      select_section(selected)
    end)
  end

  select_section = function(selected_project)
    todoist_utils.get_sections(selected_project.id, function(sections_success, sections)
      if not sections_success then
        vim.notify('Failed to fetch sections: ' .. sections, vim.log.levels.ERROR)
        return
      end

      if #sections == 0 then
        select_priority(selected_project, { name = 'No section', id = nil }, true)
        return
      end

      local section_options = {}
      for _, section in ipairs(sections) do
        table.insert(section_options, { name = section.name, id = section.id })
      end

      local section_priority_map = build_section_priority_map()
      table.sort(section_options, function(a, b)
        local a_priority = section_priority_map[a.id] or 999
        local b_priority = section_priority_map[b.id] or 999
        if a_priority ~= b_priority then return a_priority < b_priority end
        return false
      end)

      if #section_options == 1 then
        add_recent_section_id(section_options[1].id)
        select_priority(selected_project, section_options[1], true)
        return
      end

      ui_utils.add_back_option(section_options, 'Back to projects')

      ui_utils.safe_select(section_options, {
        prompt = 'Select a section:',
        format_item = format_by_name,
        on_back = function() select_project() end,
      }, function(selected_section)
        if selected_section.is_back then
          select_project()
          return
        end

        if selected_section.id then add_recent_section_id(selected_section.id) end
        select_priority(selected_project, selected_section)
      end)
    end)
  end

  select_priority = function(selected_project, selected_section, section_was_auto)
    local priority_options = vim.list_extend({}, PRIORITY_OPTIONS)
    ui_utils.add_back_option(priority_options, 'Back to sections')

    local function go_back()
      if section_was_auto then
        select_project()
      else
        select_section(selected_project)
      end
    end

    ui_utils.safe_select(priority_options, {
      prompt = 'Select a priority for the task:',
      format_item = format_by_name,
      on_back = go_back,
    }, function(selected_priority)
      if selected_priority.is_back then
        go_back()
        return
      end

      todoist_utils.create_task(task_name, selected_project.id, selected_section.id, selected_priority.value, function(task_success, response)
        if task_success then
          vim.notify(
            string.format(
              "Task '%s' created in project '%s'%s",
              task_name,
              selected_project.project.name,
              selected_section.id and (' > ' .. selected_section.name) or ''
            ),
            vim.log.levels.INFO
          )
        else
          vim.notify('Failed to create task: ' .. response, vim.log.levels.ERROR)
        end
      end, opts)
    end)
  end

  select_project()
end

local TASK_INPUT_OPTIONS = {
  { name = 'Enter title' },
  { name = 'Enter description' },
}

local function pick_file_reference(text, on_result)
  if not text:match('@%s*$') then
    on_result(text)
    return
  end

  local ok, snacks = pcall(require, 'snacks')
  if not ok then
    on_result(text)
    return
  end

  local finished = false
  local function finish(result)
    if finished then return end
    finished = true
    on_result(result)
  end

  snacks.picker.files({
    confirm = function(picker, item)
      picker:close()
      local file = item and (item.file or item.filename)
      if file then
        local rel = vim.fn.fnamemodify(file, ':.')
        finish((text:gsub('@%s*$', function() return '@' .. rel end)))
      else
        finish(text)
      end
    end,
    on_close = function() finish(text) end,
  })
end

local function prompt_task_input(on_result)
  ui_utils.safe_select(TASK_INPUT_OPTIONS, {
    prompt = 'What do you want to enter?',
    format_item = format_by_name,
  }, function(selected)
    if selected.name == 'Enter description' then
      ui_utils.multiline_input({ title = 'Task description' }, function(description)
        local opts = {}
        if description and description ~= '' then opts.description = description end
        on_result('Task', opts)
      end)
    else
      ui_utils.safe_input({ prompt = 'Enter task summary (end with @ to attach a file): ' }, function(task_name)
        pick_file_reference(task_name, function(resolved) on_result(resolved, {}) end)
      end)
    end
  end)
end

local function log_task_with_fetcher(fetch_projects, empty_message)
  return function()
    local function start_from_input()
      prompt_task_input(function(task_name, opts)
        fetch_projects(function(success, projects)
          if not success then
            vim.notify('Failed to fetch projects: ' .. projects, vim.log.levels.ERROR)
            return
          end
          if #projects == 0 then
            vim.notify(empty_message, vim.log.levels.WARN)
            return
          end
          create_task_with_navigation(task_name, projects, opts, function() start_from_input() end)
        end)
      end)
    end
    start_from_input()
  end
end

function M.log_todoist_task_all_projects() return log_task_with_fetcher(todoist_utils.get_projects, 'No projects found') end

function M.refresh_todoist_cache()
  return function()
    todoist_utils.clear_cache()
    vim.notify('Todoist cache cleared.', vim.log.levels.INFO)
  end
end

local EDIT_FIELD_OPTIONS = {
  { name = 'Edit title', field = 'title' },
  { name = 'Change priority', field = 'priority' },
  { name = 'Set due date', field = 'due' },
  { name = 'Add/edit labels', field = 'labels' },
  { name = 'Add description', field = 'description' },
  { name = 'Complete task', field = 'complete' },
}

local function edit_task_field(task, on_done)
  ui_utils.safe_select(EDIT_FIELD_OPTIONS, {
    prompt = 'Edit "' .. task.content .. '":',
    format_item = function(item) return item.name end,
  }, function(selected)
    if selected.field == 'title' then
      vim.ui.input({ prompt = 'New title: ', default = task.content }, function(new_title)
        if not new_title or new_title == '' or new_title == task.content then
          on_done()
          return
        end
        async_utils.execute(
          { 'td', 'task', 'update', 'id:' .. task.id, '--content', new_title },
          function(success, _, stderr)
            vim.schedule(function()
              if success then
                task.content = new_title
                vim.notify('Title updated', vim.log.levels.INFO)
              else
                vim.notify('Failed: ' .. stderr, vim.log.levels.ERROR)
              end
              on_done()
            end)
          end
        )
      end)
    elseif selected.field == 'priority' then
      vim.ui.select(PRIORITY_OPTIONS, {
        prompt = 'Select priority:',
        format_item = function(item) return item.name end,
      }, function(priority)
        if not priority then
          on_done()
          return
        end
        local args = { 'td', 'task', 'update', 'id:' .. task.id, '--priority', priority.value or 'p4' }
        async_utils.execute(args, function(success, _, stderr)
          vim.schedule(function()
            if success then
              vim.notify('Priority updated', vim.log.levels.INFO)
            else
              vim.notify('Failed: ' .. stderr, vim.log.levels.ERROR)
            end
            on_done()
          end)
        end)
      end)
    elseif selected.field == 'due' then
      vim.ui.input({ prompt = 'Due date (e.g. tomorrow, 2026-05-20): ' }, function(due)
        if not due or due == '' then
          on_done()
          return
        end
        async_utils.execute(
          { 'td', 'task', 'update', 'id:' .. task.id, '--due', due },
          function(success, _, stderr)
            vim.schedule(function()
              if success then
                vim.notify('Due date set: ' .. due, vim.log.levels.INFO)
              else
                vim.notify('Failed: ' .. stderr, vim.log.levels.ERROR)
              end
              on_done()
            end)
          end
        )
      end)
    elseif selected.field == 'labels' then
      vim.ui.input({ prompt = 'Labels (comma-separated): ' }, function(labels)
        if not labels or labels == '' then
          on_done()
          return
        end
        async_utils.execute(
          { 'td', 'task', 'update', 'id:' .. task.id, '--labels', labels },
          function(success, _, stderr)
            vim.schedule(function()
              if success then
                vim.notify('Labels updated', vim.log.levels.INFO)
              else
                vim.notify('Failed: ' .. stderr, vim.log.levels.ERROR)
              end
              on_done()
            end)
          end
        )
      end)
    elseif selected.field == 'description' then
      ui_utils.multiline_input({ title = 'Task description' }, function(desc)
        if not desc or desc == '' then
          on_done()
          return
        end
        async_utils.execute(
          { 'td', 'task', 'update', 'id:' .. task.id, '--description', desc },
          function(success, _, stderr)
            vim.schedule(function()
              if success then
                vim.notify('Description updated', vim.log.levels.INFO)
              else
                vim.notify('Failed: ' .. stderr, vim.log.levels.ERROR)
              end
              on_done()
            end)
          end
        )
      end)
    elseif selected.field == 'complete' then
      vim.ui.select({ 'Yes', 'No' }, {
        prompt = 'Complete "' .. task.content .. '"?',
      }, function(confirm)
        if confirm ~= 'Yes' then
          on_done()
          return
        end
        async_utils.execute(
          { 'td', 'task', 'complete', 'id:' .. task.id },
          function(success, _, stderr)
            vim.schedule(function()
              if success then
                vim.notify('Task completed: ' .. task.content, vim.log.levels.INFO)
              else
                vim.notify('Failed: ' .. stderr, vim.log.levels.ERROR)
              end
            end)
          end
        )
      end)
    end
  end)
end

function M.edit_recent_task()
  async_utils.execute({ 'td', 'task', 'list', '--json', '--full', '--limit', '20', '--all' }, function(success, stdout, stderr)
    if not success then
      vim.schedule(function() vim.notify('Failed to fetch tasks: ' .. stderr, vim.log.levels.ERROR) end)
      return
    end

    local ok, data = pcall(vim.fn.json_decode, stdout)
    if not ok or not data then
      vim.schedule(function() vim.notify('Failed to parse Todoist response', vim.log.levels.ERROR) end)
      return
    end

    local tasks = data.results or data
    if #tasks == 0 then
      vim.schedule(function() vim.notify('No recent tasks found', vim.log.levels.WARN) end)
      return
    end

    table.sort(tasks, function(a, b)
      local a_date = a.addedAt or a.added_at or ''
      local b_date = b.addedAt or b.added_at or ''
      return a_date > b_date
    end)

    local items = {}
    for i, task in ipairs(tasks) do
      if task.id and task.content and i <= 20 then
        table.insert(items, { id = tostring(task.id), content = task.content })
      end
    end

    vim.schedule(function()
      vim.ui.select(items, {
        prompt = 'Select task to edit (most recent first):',
        format_item = function(item) return item.content end,
      }, function(selected)
        if not selected then return end

        local function show_field_picker()
          edit_task_field(selected, function() show_field_picker() end)
        end
        show_field_picker()
      end)
    end)
  end)
end

function M.delete_recent_task()
  local async_utils = require('custom.utils.async')

  async_utils.execute({ 'td', 'task', 'list', '--json', '--full', '--limit', '20', '--all' }, function(success, stdout, stderr)
    if not success then
      vim.schedule(function() vim.notify('Failed to fetch tasks: ' .. stderr, vim.log.levels.ERROR) end)
      return
    end

    local ok, data = pcall(vim.fn.json_decode, stdout)
    if not ok or not data then
      vim.schedule(function() vim.notify('Failed to parse Todoist response', vim.log.levels.ERROR) end)
      return
    end

    local tasks = data.results or data
    if #tasks == 0 then
      vim.schedule(function() vim.notify('No recent tasks found', vim.log.levels.WARN) end)
      return
    end

    table.sort(tasks, function(a, b)
      local a_date = a.addedAt or a.added_at or ''
      local b_date = b.addedAt or b.added_at or ''
      return a_date > b_date
    end)

    local items = {}
    for i, task in ipairs(tasks) do
      if task.id and task.content and i <= 20 then
        table.insert(items, { id = tostring(task.id), content = task.content })
      end
    end

    vim.schedule(function()
      vim.ui.select(items, {
        prompt = 'Select task to delete (most recent first):',
        format_item = function(item) return item.content end,
      }, function(selected)
        if not selected then return end

        vim.ui.select({ 'Yes', 'No' }, {
          prompt = 'Delete "' .. selected.content .. '"?',
        }, function(confirm)
          if confirm ~= 'Yes' then return end

          async_utils.execute(
            { 'td', 'task', 'delete', 'id:' .. selected.id },
            function(delete_success, _, delete_stderr)
              vim.schedule(function()
                if delete_success then
                  vim.notify('Task deleted: ' .. selected.content, vim.log.levels.INFO)
                else
                  vim.notify('Failed to delete task: ' .. delete_stderr, vim.log.levels.ERROR)
                end
              end)
            end
          )
        end)
      end)
    end)
  end)
end

return M
